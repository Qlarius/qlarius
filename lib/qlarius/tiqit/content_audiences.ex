defmodule Qlarius.Tiqit.ContentAudiences do
  @moduledoc """
  Attach audiences to creator content and resolve what a me_file sees.

  Attachments live on `content_audience_targets`. Boosts resolve nearest-
  ancestor-wins down the piece → group → catalog → creator chain. Gates
  accumulate and are most-restrictive; an unpopulated gate is inert so
  attaching one cannot dark-launch content while the worker runs.

  Consumption is same-org: only a creator-owned target may be attached to
  that creator's content. Cross-org use goes through
  `Targets.clone_across_orgs/4` first.
  """

  import Ecto.Query

  alias Qlarius.Accounts.{Authz, Scope}
  alias Qlarius.Creators
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    Target,
    TargetBand,
    TargetBandTraitGroup,
    TargetPopulation,
    Targets,
    TraitGroup,
    TraitGroupTrait
  }

  alias Qlarius.Tiqit.Arcade.{Arcade, Catalog, ContentGroup, ContentPiece}
  alias Qlarius.Tiqit.ContentAudienceTarget
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait

  @levels [:piece, :group, :catalog, :creator]
  @level_rank %{piece: 0, group: 1, catalog: 2, creator: 3}
  @level_fk %{
    piece: :content_piece_id,
    group: :content_group_id,
    catalog: :catalog_id,
    creator: :creator_id
  }

  # --- Attach / detach ---

  @doc """
  Sets the audience at `content`'s level for `mode`, replacing any existing
  attachment at that slot. `content` is a Creator, Catalog, ContentGroup, or
  ContentPiece.
  """
  def set_attachment(%Scope{} = scope, %Target{} = target, content, mode)
      when mode in [:boost, :gate] do
    with {:ok, creator_id, level, level_id} <- locate(content),
         :ok <- authorize_creator(scope, creator_id),
         :ok <- same_org(target, creator_id) do
      Repo.transaction(fn ->
        clear_slot!(mode, level, level_id)

        %ContentAudienceTarget{}
        |> ContentAudienceTarget.changeset(
          %{target_id: target.id, mode: mode}
          |> Map.put(@level_fk[level], level_id)
        )
        |> Repo.insert()
        |> case do
          {:ok, attachment} -> attachment
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc """
  Removes the audience at `content`'s level for `mode`.
  """
  def clear_attachment(%Scope{} = scope, content, mode) when mode in [:boost, :gate] do
    with {:ok, creator_id, level, level_id} <- locate(content),
         :ok <- authorize_creator(scope, creator_id) do
      {count, _} =
        from(a in ContentAudienceTarget,
          where: a.mode == ^mode and field(a, ^@level_fk[level]) == ^level_id
        )
        |> Repo.delete_all()

      {:ok, count}
    end
  end

  def attachments_on(content) do
    {:ok, _creator_id, level, level_id} = locate(content)

    from(a in ContentAudienceTarget,
      where: field(a, ^@level_fk[level]) == ^level_id,
      preload: [target: [target_bands: [trait_groups: :traits]]]
    )
    |> Repo.all()
  end

  # --- Matches and gates ---

  @doc """
  What this me_file matches, keyed by attachment level.

  Because a population row records only the innermost matching band,
  `tier` on that row is already the user's best tier for that audience.
  """
  def matches_for_me_file(nil), do: empty_matches()

  def matches_for_me_file(me_file_id) when is_integer(me_file_id) do
    rows =
      from(tp in TargetPopulation,
        join: tb in TargetBand,
        on: tb.id == tp.target_band_id,
        join: a in ContentAudienceTarget,
        on: a.target_id == tb.target_id,
        where: tp.me_file_id == ^me_file_id,
        select: %{
          mode: a.mode,
          creator_id: a.creator_id,
          catalog_id: a.catalog_id,
          content_group_id: a.content_group_id,
          content_piece_id: a.content_piece_id,
          target_id: tb.target_id,
          band_id: tb.id,
          tier: tb.tier,
          population_count: tb.population_count,
          snapshot: tp.matching_tags_snapshot
        }
      )
      |> Repo.all()

    condition_counts = condition_counts_for(Enum.map(rows, & &1.band_id))

    Enum.reduce(rows, empty_matches(), fn row, acc ->
      match = %{
        target_id: row.target_id,
        band_id: row.band_id,
        tier: row.tier || 0,
        population_count: row.population_count || 0,
        condition_count: Map.get(condition_counts, row.band_id, 0),
        snapshot: row.snapshot
      }

      case {row.mode, level_of(row)} do
        {:boost, level} ->
          put_in(acc, [:boosts, level, level_id(row, level)], match)

        {:gate, _level} ->
          update_in(acc, [:matched_gate_ids], &MapSet.put(&1, row.target_id))

        _ ->
          acc
      end
    end)
  end

  @doc """
  Every gate attachment, user-independent. Unpopulated targets are included
  so `resolve/2` can treat them as inert rather than as a hide.
  """
  def gate_attachments do
    from(a in ContentAudienceTarget,
      join: t in Target,
      on: t.id == a.target_id,
      where: a.mode == :gate,
      select: %{
        target_id: a.target_id,
        populated?: t.population_status == "populated",
        creator_id: a.creator_id,
        catalog_id: a.catalog_id,
        content_group_id: a.content_group_id,
        content_piece_id: a.content_piece_id
      }
    )
    |> Repo.all()
    |> Enum.reduce(empty_levels(), fn row, acc ->
      case level_of(row) do
        nil ->
          acc

        level ->
          entry = %{target_id: row.target_id, populated?: row.populated?}
          update_in(acc, [level, level_id(row, level)], &[entry | &1 || []])
      end
    end)
  end

  def empty_matches do
    %{boosts: empty_levels(), matched_gate_ids: MapSet.new()}
  end

  # --- Resolution ---

  @doc """
  Single inheritance implementation used by the discovery feed and the
  creator UI, so they cannot disagree.

  `ancestry` is `%{piece:, group:, catalog:, creator:}` — any prefix may be
  nil. `matches` comes from `matches_for_me_file/1`. `gates` comes from
  `gate_attachments/0`.
  """
  def resolve(ancestry, matches, gates \\ nil) do
    gates = gates || empty_levels()
    boost = nearest_boost(ancestry, matches.boosts)
    applied_gates = accumulating_gates(ancestry, gates)

    blocking =
      Enum.filter(applied_gates, fn gate ->
        gate.populated? and not MapSet.member?(matches.matched_gate_ids, gate.target_id)
      end)

    %{
      boost_tier: boost && boost.tier,
      boost_source: boost && boost.level,
      boost_match: boost,
      visible?: blocking == [],
      blocking_gates: Enum.map(blocking, & &1.target_id),
      applied_gates: applied_gates,
      rank: rank_tuple(boost, ancestry),
      matched_traits: boost && boost.snapshot
    }
  end

  @doc """
  Creator-facing counterpart of `resolve/2`: which audience is in effect
  at this level, and what would be inherited if it were cleared.
  """
  def effective_audience(content) do
    {:ok, _creator_id, level, _id} = locate(content)
    ancestry = ancestry_for(content)
    here = attachments_on(content)

    boost_here = Enum.find(here, &(&1.mode == :boost))
    gate_here = Enum.find(here, &(&1.mode == :gate))

    inherited_boost = inherited_boost_above(ancestry, level)
    inherited_gates = inherited_gates_above(ancestry, level)

    %{
      level: level,
      boost: slot(boost_here, inherited_boost),
      gate: slot(gate_here, nil),
      inherited_gates: inherited_gates
    }
  end

  @doc """
  Whether a piece is reachable by this scope. Entitled users (a valid
  tiqit) bypass gates so past purchases never vanish. Anonymous visitors
  satisfy no gates and get no boosts.
  """
  def piece_visible?(%Scope{} = scope, %ContentPiece{} = piece) do
    ancestry = ancestry_for(piece)
    matches = matches_for_scope(scope)
    result = resolve(ancestry, matches, gate_attachments())

    result.visible? or entitled?(scope, piece)
  end

  def piece_visible?(nil, %ContentPiece{} = piece) do
    resolve(ancestry_for(piece), empty_matches(), gate_attachments()).visible?
  end

  def matches_for_scope(%Scope{user: %{me_file: %{id: id}}}), do: matches_for_me_file(id)

  def matches_for_scope(%Scope{user: %{me_file_id: id}}) when is_integer(id),
    do: matches_for_me_file(id)

  def matches_for_scope(_), do: empty_matches()

  @doc """
  The two lookups discovery needs once per request: this user's matches
  plus the user-independent gate map.
  """
  def discovery_lookups(scope) do
    {matches_for_scope(scope), gate_attachments()}
  end

  def resolve_group(group, matches, gates) do
    resolve(ancestry_for(group), matches, gates)
  end

  def resolve_piece(piece, matches, gates) do
    resolve(ancestry_for(piece), matches, gates)
  end

  @doc """
  Short "Why you?" label from the matched band's snapshot. Reads the
  parsed parent names — never `inspect/1` of the map.
  """
  def why_you_label(%{matched_traits: snapshot, boost_source: source})
      when source != nil do
    names =
      snapshot
      |> Targets.snapshot_to_tuples()
      |> Enum.map(fn {_id, name, _order, _children} -> name end)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(2)

    case names do
      [] -> nil
      [one] -> "Because you're into #{one}"
      [a, b] -> "Because you're into #{a} and #{b}"
    end
  end

  def why_you_label(_), do: nil

  @doc """
  Full "Why you?" payload for group and piece pages: short label, who
  attached the audience, and parsed trait tuples for `parent_traits_display`.
  """
  def why_you(scope, content) do
    ancestry = ancestry_for(content)
    result = resolve(ancestry, matches_for_scope(scope), gate_attachments())
    why_you_from_resolve(result, ancestry)
  end

  def why_you_from_resolve(%{boost_source: nil}, _ancestry), do: nil

  def why_you_from_resolve(result, ancestry) do
    %{
      label: why_you_label(result),
      source_copy: why_you_source(result.boost_source, ancestry),
      parent_traits: Targets.snapshot_to_tuples(result.matched_traits || %{})
    }
  end

  defp why_you_source(level, ancestry) do
    creator_name =
      case ancestry do
        %{creator: %{name: name}} when is_binary(name) -> name
        _ -> "This creator"
      end

    catalog = Map.get(ancestry, :catalog)
    piece_type = (catalog && catalog.piece_type) || :episode
    group_type = (catalog && catalog.group_type) || :show

    case level do
      :piece -> "#{creator_name} set this audience for this #{piece_type}"
      :group -> "#{creator_name} set this audience for this #{group_type}"
      :catalog -> "#{creator_name} set this audience for this catalog"
      :creator -> "#{creator_name} set this audience for everything they make"
      _ -> "#{creator_name} recommended this because of your tags"
    end
  end

  # --- Ancestry ---

  def ancestry_for(%ContentPiece{} = piece) do
    piece = Repo.preload(piece, content_group: [catalog: :creator])
    group = piece.content_group
    catalog = group && group.catalog

    %{
      piece: piece,
      group: group,
      catalog: catalog,
      creator: catalog && catalog.creator
    }
  end

  def ancestry_for(%ContentGroup{} = group) do
    group = Repo.preload(group, catalog: :creator)
    catalog = group.catalog

    %{
      piece: nil,
      group: group,
      catalog: catalog,
      creator: catalog && catalog.creator
    }
  end

  def ancestry_for(%Catalog{} = catalog) do
    catalog = Repo.preload(catalog, :creator)

    %{piece: nil, group: nil, catalog: catalog, creator: catalog.creator}
  end

  def ancestry_for(%Creator{} = creator) do
    %{piece: nil, group: nil, catalog: nil, creator: creator}
  end

  # --- Builder ---

  @doc """
  Creates an empty creator-owned audience.
  """
  def create_audience(%Scope{} = scope, creator_id, attrs) when is_integer(creator_id) do
    with :ok <- authorize_creator(scope, creator_id) do
      attrs =
        attrs
        |> Map.new()
        |> Map.put(:creator_id, creator_id)
        |> Map.put(:user_created_by, Authz.acting_user_id(scope))

      Targets.create_target(attrs)
    end
  end

  @doc """
  Creates a creator-owned trait group from a parent trait's answers and
  adds it to the audience bullseye. Re-tagging the same parent updates
  the existing group via `set_question_answers/4`.
  """
  def create_starter_group(scope, target, parent_trait_id, child_trait_ids, opts \\ [])

  def create_starter_group(
        %Scope{} = scope,
        %Target{} = target,
        parent_trait_id,
        child_trait_ids,
        opts
      )
      when is_integer(parent_trait_id) and is_list(child_trait_ids) do
    with :ok <- authorize_target(scope, target) do
      target = Repo.preload(target, target_bands: [trait_groups: :traits])
      existing = Enum.find(groups_on(target), &(&1.parent_trait_id == parent_trait_id))

      if existing do
        set_question_answers(scope, target, parent_trait_id, child_trait_ids)
      else
        parent = Repo.get!(Trait, parent_trait_id)
        child_trait_ids = Enum.uniq(child_trait_ids)
        title = starter_title(opts, parent)

        Repo.transaction(fn ->
          attrs = %{
            "title" => title,
            "creator_id" => target.creator_id,
            "parent_trait_id" => parent_trait_id,
            "user_created_by" => Authz.acting_user_id(scope),
            "trait_ids" => child_trait_ids
          }

          group =
            case Traits.create_trait_group(attrs) do
              {:ok, g} -> g
              {:error, cs} -> Repo.rollback(cs)
            end

          bullseye = bullseye_or_create!(target, Authz.acting_user_id(scope))

          case Targets.add_trait_group_to_band(bullseye.id, group.id) do
            {:ok, _} -> group
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
      end
    end
  end

  @doc """
  Lists audiences owned by this creator.
  """
  def list_audiences(creator_id) when is_integer(creator_id) do
    from(t in Target,
      where: t.creator_id == ^creator_id,
      order_by: [desc: t.created_at],
      preload: [target_bands: [trait_groups: :traits]]
    )
    |> Repo.all()
    |> Enum.map(&put_usage/1)
  end

  def get_audience!(creator_id, target_id) do
    from(t in Target, where: t.id == ^target_id and t.creator_id == ^creator_id)
    |> Repo.one!()
    |> Repo.preload(target_bands: [trait_groups: :traits])
  end

  @doc """
  Sets the answers a target asks for one survey question.

  One trait group per question. If the group is shared with another target
  it is forked first (copy-on-write), so editing never silently changes a
  sibling audience.
  """
  def set_question_answers(%Scope{} = scope, %Target{} = target, parent_trait_id, child_trait_ids)
      when is_integer(parent_trait_id) and is_list(child_trait_ids) do
    with :ok <- authorize_target(scope, target) do
      target = Repo.preload(target, target_bands: [trait_groups: :traits])
      child_trait_ids = Enum.uniq(child_trait_ids)

      Repo.transaction(fn ->
        bullseye = bullseye_or_create!(target, Authz.acting_user_id(scope))
        existing = Enum.find(groups_on(target), &(&1.parent_trait_id == parent_trait_id))

        cond do
          child_trait_ids == [] and existing ->
            Targets.remove_trait_group_from_band(bullseye.id, existing.id)
            existing

          child_trait_ids == [] ->
            nil

          existing && shared_group?(existing.id) ->
            forked = fork_group!(existing, target, child_trait_ids, Authz.acting_user_id(scope))
            replace_group_on_target!(target, existing.id, forked.id)
            forked

          existing ->
            replace_group_traits!(existing, child_trait_ids)
            existing

          true ->
            group =
              insert_group!(target, parent_trait_id, child_trait_ids, Authz.acting_user_id(scope))

            case Targets.add_trait_group_to_band(bullseye.id, group.id) do
              {:ok, _} -> group
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
    end
  end

  @doc """
  Structural copy that shares trait groups — the same-org refine path.
  """
  def copy_within_org(%Scope{} = scope, %Target{} = source, opts \\ []) do
    with :ok <- authorize_target(scope, source) do
      source = Repo.preload(source, [target_bands: [trait_groups: :traits]], force: true)
      created_by = Authz.acting_user_id(scope)
      title = Keyword.get(opts, :title, "#{source.title} (refined)")

      Repo.transaction(fn ->
        clone =
          case Targets.create_target(%{
                 title: title,
                 description: source.description,
                 creator_id: source.creator_id,
                 marketer_id: source.marketer_id,
                 user_created_by: created_by,
                 population_status: "not_populated"
               }) do
            {:ok, t} -> t
            {:error, cs} -> Repo.rollback(cs)
          end

        Enum.each(source.target_bands, fn band ->
          {:ok, cloned_band} =
            %TargetBand{}
            |> TargetBand.changeset(%{
              target_id: clone.id,
              is_bullseye: band.is_bullseye || "0",
              user_created_by: created_by
            })
            |> Repo.insert()

          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          rows =
            Enum.map(band.trait_groups, fn group ->
              %{
                target_band_id: cloned_band.id,
                trait_group_id: group.id,
                created_at: now,
                updated_at: now
              }
            end)

          if rows != [], do: Repo.insert_all(TargetBandTraitGroup, rows)
        end)

        Repo.preload(clone, [target_bands: [trait_groups: :traits]], force: true)
      end)
    end
  end

  def broaden(%Target{} = target, excluded_trait_group_id) do
    Targets.create_outer_band(target.id, excluded_trait_group_id)
  end

  def reach(%Target{} = target) do
    from(tp in TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target.id,
      select: count(tp.id)
    )
    |> Repo.one() || 0
  end

  def list_questions(search \\ "") do
    TraitManager.list_parent_traits(nil, search)
  end

  def list_answers(parent_trait_id) do
    from(t in Trait,
      where: t.parent_trait_id == ^parent_trait_id and t.is_active == true,
      order_by: [asc: t.display_order, asc: t.trait_name]
    )
    |> Repo.all()
  end

  def trigger_population(%Target{} = target), do: Targets.trigger_population(target)

  # --- internals ---

  defp starter_title(opts, parent) do
    case Keyword.get(opts, :title) do
      title when is_binary(title) ->
        trimmed = String.trim(title)
        if trimmed == "", do: parent.trait_name, else: trimmed

      _ ->
        parent.trait_name
    end
  end

  defp locate(%Creator{id: id}), do: {:ok, id, :creator, id}

  defp locate(%Catalog{id: id, creator_id: creator_id}) when is_integer(creator_id),
    do: {:ok, creator_id, :catalog, id}

  defp locate(%Catalog{} = catalog) do
    catalog = Repo.preload(catalog, :creator)
    {:ok, catalog.creator_id, :catalog, catalog.id}
  end

  defp locate(%ContentGroup{} = group) do
    group = Repo.preload(group, :catalog)
    {:ok, group.catalog.creator_id, :group, group.id}
  end

  defp locate(%ContentPiece{} = piece) do
    piece = Repo.preload(piece, content_group: :catalog)
    {:ok, piece.content_group.catalog.creator_id, :piece, piece.id}
  end

  defp locate(_), do: {:error, :unknown_content}

  defp authorize_creator(%Scope{} = scope, creator_id) do
    if Authz.admin?(scope) or
         (Authz.acting_user_id(scope) &&
            Creators.user_has_creator_access?(Authz.acting_user_id(scope), creator_id)) do
      if Repo.exists?(from c in Creator, where: c.id == ^creator_id) do
        :ok
      else
        {:error, :unauthorized}
      end
    else
      {:error, :unauthorized}
    end
  end

  defp authorize_target(scope, %Target{creator_id: id}) when is_integer(id),
    do: authorize_creator(scope, id)

  defp authorize_target(_scope, _target), do: {:error, :unauthorized}

  defp same_org(%Target{creator_id: id}, id) when is_integer(id), do: :ok
  defp same_org(_target, _creator_id), do: {:error, :wrong_owner}

  defp clear_slot!(mode, level, level_id) do
    from(a in ContentAudienceTarget,
      where: a.mode == ^mode and field(a, ^@level_fk[level]) == ^level_id
    )
    |> Repo.delete_all()
  end

  defp empty_levels, do: %{creator: %{}, catalog: %{}, group: %{}, piece: %{}}

  defp level_of(%{content_piece_id: id}) when not is_nil(id), do: :piece
  defp level_of(%{content_group_id: id}) when not is_nil(id), do: :group
  defp level_of(%{catalog_id: id}) when not is_nil(id), do: :catalog
  defp level_of(%{creator_id: id}) when not is_nil(id), do: :creator
  defp level_of(_), do: nil

  defp level_id(row, :piece), do: row.content_piece_id
  defp level_id(row, :group), do: row.content_group_id
  defp level_id(row, :catalog), do: row.catalog_id
  defp level_id(row, :creator), do: row.creator_id

  defp condition_counts_for([]), do: %{}

  defp condition_counts_for(band_ids) do
    from(tbtg in TargetBandTraitGroup,
      where: tbtg.target_band_id in ^band_ids,
      group_by: tbtg.target_band_id,
      select: {tbtg.target_band_id, count(tbtg.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp nearest_boost(ancestry, boosts) do
    Enum.find_value(@levels, fn level ->
      case id_at(ancestry, level) do
        nil ->
          nil

        id ->
          case get_in(boosts, [level, id]) do
            nil -> nil
            match -> Map.put(match, :level, level)
          end
      end
    end)
  end

  defp accumulating_gates(ancestry, gates) do
    Enum.flat_map(@levels, fn level ->
      case id_at(ancestry, level) do
        nil -> []
        id -> Enum.map(Map.get(gates[level], id, []), &Map.put(&1, :level, level))
      end
    end)
  end

  defp id_at(%{piece: %{id: id}}, :piece), do: id
  defp id_at(%{group: %{id: id}}, :group), do: id
  defp id_at(%{catalog: %{id: id}}, :catalog), do: id
  defp id_at(%{creator: %{id: id}}, :creator), do: id
  defp id_at(_, _), do: nil

  defp rank_tuple(nil, _ancestry), do: nil

  defp rank_tuple(boost, ancestry) do
    {
      selectivity_bucket(boost.population_count),
      -boost.condition_count,
      Map.fetch!(@level_rank, boost.level),
      -recency_unix(ancestry),
      id_at(ancestry, :piece) || id_at(ancestry, :group) || 0
    }
  end

  defp selectivity_bucket(count) when count < 1_000, do: 0
  defp selectivity_bucket(count) when count < 10_000, do: 1
  defp selectivity_bucket(count) when count < 100_000, do: 2
  defp selectivity_bucket(_count), do: 3

  defp recency_unix(%{piece: %{date_published: %Date{} = date}}), do: Date.to_gregorian_days(date)

  defp recency_unix(%{group: %{content_pieces: pieces}}) when is_list(pieces) do
    pieces
    |> Enum.map(& &1.date_published)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Date.to_gregorian_days/1)
    |> Enum.max(fn -> 0 end)
  end

  defp recency_unix(_), do: 0

  defp inherited_boost_above(ancestry, level) do
    above = levels_above(level)

    Enum.find_value(above, fn lvl ->
      case id_at(ancestry, lvl) do
        nil ->
          nil

        id ->
          from(a in ContentAudienceTarget,
            join: t in Target,
            on: t.id == a.target_id,
            where: a.mode == :boost and field(a, ^@level_fk[lvl]) == ^id,
            preload: [target: [target_bands: []]],
            limit: 1
          )
          |> Repo.one()
          |> case do
            nil -> nil
            attachment -> %{level: lvl, attachment: attachment, target: attachment.target}
          end
      end
    end)
  end

  defp inherited_gates_above(ancestry, level) do
    Enum.flat_map(levels_above(level), fn lvl ->
      case id_at(ancestry, lvl) do
        nil ->
          []

        id ->
          from(a in ContentAudienceTarget,
            join: t in Target,
            on: t.id == a.target_id,
            where: a.mode == :gate and field(a, ^@level_fk[lvl]) == ^id,
            preload: [:target]
          )
          |> Repo.all()
          |> Enum.map(&%{level: lvl, attachment: &1, target: &1.target})
      end
    end)
  end

  defp levels_above(:piece), do: [:group, :catalog, :creator]
  defp levels_above(:group), do: [:catalog, :creator]
  defp levels_above(:catalog), do: [:creator]
  defp levels_above(:creator), do: []

  defp slot(nil, nil), do: %{state: :unset, attachment: nil, inherited: nil}
  defp slot(nil, inherited), do: %{state: :inheriting, attachment: nil, inherited: inherited}
  defp slot(here, inherited), do: %{state: :set_here, attachment: here, inherited: inherited}

  defp entitled?(scope, piece), do: Arcade.get_valid_tiqit(scope, piece) != nil

  defp put_usage(target) do
    used_on =
      from(a in ContentAudienceTarget,
        where: a.target_id == ^target.id,
        select: %{
          mode: a.mode,
          creator_id: a.creator_id,
          catalog_id: a.catalog_id,
          content_group_id: a.content_group_id,
          content_piece_id: a.content_piece_id
        }
      )
      |> Repo.all()

    Map.put(target, :used_on, used_on)
  end

  defp groups_on(target) do
    target.target_bands
    |> Enum.flat_map(& &1.trait_groups)
    |> Enum.uniq_by(& &1.id)
  end

  defp bullseye_or_create!(target, created_by) do
    case Targets.get_bullseye_for_target(target.id) do
      nil ->
        {:ok, band} =
          Targets.create_bullseye_band(target.id, %{
            "user_created_by" => created_by
          })

        band

      band ->
        band
    end
  end

  defp shared_group?(trait_group_id) do
    from(tbtg in TargetBandTraitGroup,
      join: tb in TargetBand,
      on: tb.id == tbtg.target_band_id,
      where: tbtg.trait_group_id == ^trait_group_id,
      select: tb.target_id,
      distinct: true
    )
    |> Repo.aggregate(:count) > 1
  end

  defp insert_group!(target, parent_trait_id, child_trait_ids, created_by) do
    parent = Repo.get!(Trait, parent_trait_id)

    {:ok, group} =
      %TraitGroup{}
      |> TraitGroup.changeset(%{
        title: parent.trait_name,
        parent_trait_id: parent_trait_id,
        creator_id: target.creator_id,
        marketer_id: target.marketer_id,
        user_created_by: created_by
      })
      |> Repo.insert()

    replace_group_traits!(group, child_trait_ids)
    group
  end

  defp replace_group_traits!(group, child_trait_ids) do
    from(tgt in TraitGroupTrait, where: tgt.trait_group_id == ^group.id)
    |> Repo.delete_all()

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      Enum.map(child_trait_ids, fn trait_id ->
        %{
          trait_group_id: group.id,
          trait_id: trait_id,
          created_at: now,
          updated_at: now
        }
      end)

    if rows != [], do: Repo.insert_all(TraitGroupTrait, rows)
    group
  end

  defp fork_group!(existing, target, child_trait_ids, created_by) do
    {:ok, group} =
      %TraitGroup{}
      |> TraitGroup.changeset(%{
        title: existing.title,
        description: existing.description,
        parent_trait_id: existing.parent_trait_id,
        creator_id: target.creator_id,
        marketer_id: target.marketer_id,
        user_created_by: created_by
      })
      |> Repo.insert()

    replace_group_traits!(group, child_trait_ids)
    group
  end

  defp replace_group_on_target!(target, old_id, new_id) do
    band_ids = Enum.map(target.target_bands, & &1.id)

    from(tbtg in TargetBandTraitGroup,
      where: tbtg.target_band_id in ^band_ids and tbtg.trait_group_id == ^old_id
    )
    |> Repo.update_all(set: [trait_group_id: new_id])
  end
end
