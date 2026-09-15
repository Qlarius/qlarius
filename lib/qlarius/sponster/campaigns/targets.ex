defmodule Qlarius.Sponster.Campaigns.Targets do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Accounts.{Authz, Marketer, Marketers, Scope}
  alias Qlarius.Creators
  alias Qlarius.Creators.Creator

  alias Qlarius.Sponster.Campaigns.{
    Target,
    TargetBand,
    TargetBandTraitGroup,
    TraitGroup,
    TraitGroupTrait
  }

  def list_targets_for_marketer(marketer_id) do
    from(t in Target,
      where: t.marketer_id == ^marketer_id,
      order_by: [desc: t.created_at],
      preload: [target_bands: [:trait_groups]]
    )
    |> Repo.all()
    |> Enum.map(&add_target_stats/1)
  end

  def get_target_for_marketer!(id, marketer_id) do
    from(t in Target,
      where: t.id == ^id and t.marketer_id == ^marketer_id,
      preload: [target_bands: [trait_groups: [], target_band_trait_groups: []]]
    )
    |> Repo.one!()
    |> add_target_stats()
  end

  def create_target(attrs) do
    %Target{}
    |> Target.changeset(attrs)
    |> Repo.insert()
  end

  def update_target(%Target{} = target, attrs) do
    target
    |> Target.changeset(attrs)
    |> Repo.update()
  end

  def delete_target(%Target{} = target) do
    Repo.delete(target)
  end

  def create_bullseye_band(target_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put("target_id", target_id)
      |> Map.put("is_bullseye", "1")

    %TargetBand{}
    |> TargetBand.changeset(attrs)
    |> Repo.insert()
  end

  def get_bullseye_for_target(target_id) do
    from(tb in TargetBand,
      where: tb.target_id == ^target_id and tb.is_bullseye == "1",
      preload: [:trait_groups]
    )
    |> Repo.one()
  end

  def get_target_band!(id) do
    from(tb in TargetBand,
      where: tb.id == ^id,
      preload: [:trait_groups, :target]
    )
    |> Repo.one!()
  end

  def add_trait_group_to_band(band_id, trait_group_id) do
    existing =
      from(tbtg in TargetBandTraitGroup,
        join: tb in TargetBand,
        on: tbtg.target_band_id == tb.id,
        where: tb.target_id == ^get_target_id_for_band(band_id),
        where: tbtg.trait_group_id == ^trait_group_id
      )
      |> Repo.one()

    if existing do
      {:error, :trait_group_already_in_target}
    else
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      %TargetBandTraitGroup{}
      |> TargetBandTraitGroup.changeset(%{
        target_band_id: band_id,
        trait_group_id: trait_group_id
      })
      |> Ecto.Changeset.put_change(:created_at, now)
      |> Ecto.Changeset.put_change(:updated_at, now)
      |> Repo.insert()
    end
  end

  def remove_trait_group_from_band(band_id, trait_group_id) do
    from(tbtg in TargetBandTraitGroup,
      where: tbtg.target_band_id == ^band_id and tbtg.trait_group_id == ^trait_group_id
    )
    |> Repo.delete_all()

    {:ok, :removed}
  end

  def create_outer_band(target_id, excluded_trait_group_id) do
    outermost_band = get_outermost_band(target_id)

    if !outermost_band do
      {:error, :no_bands_exist}
    else
      trait_group_ids =
        outermost_band.trait_groups
        |> Enum.map(& &1.id)
        |> Enum.reject(&(&1 == excluded_trait_group_id))

      if trait_group_ids == [] do
        {:error, :cannot_create_empty_band}
      else
        {:ok, new_band} =
          %TargetBand{}
          |> TargetBand.changeset(%{
            target_id: target_id,
            is_bullseye: "0",
            user_created_by: outermost_band.user_created_by
          })
          |> Repo.insert()

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        associations =
          Enum.map(trait_group_ids, fn tg_id ->
            %{
              target_band_id: new_band.id,
              trait_group_id: tg_id,
              created_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(TargetBandTraitGroup, associations)

        {:ok, new_band}
      end
    end
  end

  def delete_outermost_band(target_id) do
    outermost_band = get_outermost_band(target_id)

    if !outermost_band do
      {:error, :no_bands_to_delete}
    else
      if outermost_band.is_bullseye == "1" do
        {:error, :cannot_delete_bullseye}
      else
        Repo.delete(outermost_band)
      end
    end
  end

  def get_bands_for_target(target_id) do
    from(tb in TargetBand,
      where: tb.target_id == ^target_id,
      preload: [trait_groups: [:traits]]
    )
    |> Repo.all()
    |> sort_bands_by_trait_count()
  end

  def get_outermost_band(target_id) do
    bands = get_bands_for_target(target_id)

    bands
    |> Enum.min_by(&length(&1.trait_groups), fn -> nil end)
  end

  def get_available_trait_groups_for_target(target_id, marketer_id) do
    used_trait_group_ids =
      from(tbtg in TargetBandTraitGroup,
        join: tb in TargetBand,
        on: tbtg.target_band_id == tb.id,
        where: tb.target_id == ^target_id,
        select: tbtg.trait_group_id
      )
      |> Repo.all()

    from(tg in TraitGroup,
      where: tg.marketer_id == ^marketer_id,
      where: is_nil(tg.deactivated_at),
      where: tg.id not in ^used_trait_group_ids,
      order_by: [asc: tg.title],
      preload: [:traits]
    )
    |> Repo.all()
  end

  def trigger_population(%Target{} = target) do
    {:ok, _target} = update_target(target, %{population_status: "populating"})

    {:ok, _job} =
      %{target_id: target.id}
      |> Qlarius.Jobs.PopulateTargetWorker.new(queue: :targets)
      |> Oban.insert()

    :ok
  end

  @doc """
  Deep-copies a target into another organization.

  The receiving org gets its own `targets` row, its own bands, and its own
  `trait_groups` with the owner rewritten. Sharing trait-group rows across an
  org boundary would leak ownership, so this is never a structural share —
  same-org refinement, which *does* share groups, lives elsewhere.

  Authorized by access to **both** orgs, using the same admin-bypass rules as
  `Marketers.accessible_marketer!/2` and `Creators.accessible_creator!/2`.
  Attribution (`user_created_by`) records `Authz.acting_user_id/1`, not the
  bypass.

  `dest` is `{:marketer, id}` or `{:creator, id}`. Returns
  `{:ok, clone}`, `{:error, :unauthorized}`, `{:error, :same_org}`,
  `{:error, :foreign_trait_group}`, or `{:error, changeset}`.

  The clone is unpopulated. Pass `populate: true` to enqueue
  `PopulateTargetWorker` after the copy — the default is off so a caller that
  wants to inspect or further edit the structure is not racing a worker.
  """
  def clone_across_orgs(%Scope{} = scope, %Target{} = source, dest, opts \\ []) do
    source_owner = owner_tuple(source)
    dest_owner = normalize_dest(dest)

    with :ok <- authorize_owner(scope, source_owner),
         :ok <- authorize_owner(scope, dest_owner),
         :ok <- reject_same_org(source_owner, dest_owner) do
      created_by = Authz.acting_user_id(scope)
      title = Keyword.get(opts, :title, source.title)

      case Repo.transaction(fn ->
             do_clone_across_orgs(source, dest_owner, title, created_by)
           end) do
        {:ok, clone} ->
          if Keyword.get(opts, :populate, false), do: trigger_population(clone)
          {:ok, reload_clone(clone)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_clone_across_orgs(source, dest_owner, title, created_by) do
    source = Repo.preload(source, [target_bands: [trait_groups: :traits]], force: true)
    owner_attrs = owner_attrs(dest_owner)

    clone =
      insert!(
        %Target{},
        %{
          title: title,
          description: source.description,
          user_created_by: created_by,
          population_status: "not_populated"
        }
        |> Map.merge(owner_attrs)
      )

    group_id_map =
      source.target_bands
      |> Enum.flat_map(& &1.trait_groups)
      |> Enum.uniq_by(& &1.id)
      |> Map.new(fn group ->
        unless owned_by?(group, owner_tuple(source)) do
          Repo.rollback(:foreign_trait_group)
        end

        {group.id, clone_trait_group!(group, owner_attrs, created_by).id}
      end)

    Enum.each(source.target_bands, fn band ->
      cloned_band =
        insert!(%TargetBand{}, %{
          target_id: clone.id,
          is_bullseye: band.is_bullseye || "0",
          user_created_by: created_by
        })

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      associations =
        Enum.map(band.trait_groups, fn group ->
          %{
            target_band_id: cloned_band.id,
            trait_group_id: Map.fetch!(group_id_map, group.id),
            created_at: now,
            updated_at: now
          }
        end)

      if associations != [], do: Repo.insert_all(TargetBandTraitGroup, associations)
    end)

    clone
  end

  defp clone_trait_group!(group, owner_attrs, created_by) do
    cloned =
      insert!(
        %TraitGroup{},
        %{
          title: group.title,
          description: group.description,
          parent_trait_id: group.parent_trait_id,
          user_created_by: created_by
        }
        |> Map.merge(owner_attrs)
      )

    for trait <- group.traits do
      insert!(%TraitGroupTrait{}, %{
        trait_group_id: cloned.id,
        trait_id: trait.id
      })
    end

    cloned
  end

  defp insert!(%schema{} = struct, attrs) do
    changeset = schema.changeset(struct, attrs)

    case Repo.insert(changeset) do
      {:ok, row} -> row
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp reload_clone(%Target{} = clone) do
    Repo.preload(clone, [target_bands: [trait_groups: :traits]], force: true)
  end

  defp normalize_dest({:marketer, id}) when is_integer(id), do: {:marketer, id}
  defp normalize_dest({:creator, id}) when is_integer(id), do: {:creator, id}

  defp owner_tuple(%{marketer_id: id, creator_id: nil}) when is_integer(id), do: {:marketer, id}
  defp owner_tuple(%{creator_id: id, marketer_id: nil}) when is_integer(id), do: {:creator, id}
  defp owner_tuple(%{marketer_id: id}) when is_integer(id), do: {:marketer, id}
  defp owner_tuple(%{creator_id: id}) when is_integer(id), do: {:creator, id}

  defp owner_attrs({:marketer, id}), do: %{marketer_id: id}
  defp owner_attrs({:creator, id}), do: %{creator_id: id}

  defp owned_by?(%{marketer_id: id}, {:marketer, id}), do: true
  defp owned_by?(%{creator_id: id}, {:creator, id}), do: true
  defp owned_by?(_group, _owner), do: false

  defp reject_same_org(owner, owner), do: {:error, :same_org}
  defp reject_same_org(_source, _dest), do: :ok

  # Mirrors `accessible_*!/2` without raising, so a LiveView can pattern-match
  # instead of rescuing. Admin bypass still reads `true_user` via `Authz.admin?/1`.
  defp authorize_owner(scope, {:marketer, id}) do
    reachable? =
      if Authz.admin?(scope) do
        Repo.exists?(from m in Marketer, where: m.id == ^id)
      else
        case Authz.acting_user_id(scope) do
          nil -> false
          user_id -> Marketers.user_has_marketer_access?(user_id, id)
        end
      end

    if reachable?, do: :ok, else: {:error, :unauthorized}
  end

  defp authorize_owner(scope, {:creator, id}) do
    reachable? =
      if Authz.admin?(scope) do
        Repo.exists?(from c in Creator, where: c.id == ^id)
      else
        case Authz.acting_user_id(scope) do
          nil -> false
          user_id -> Creators.user_has_creator_access?(user_id, id)
        end
      end

    if reachable?, do: :ok, else: {:error, :unauthorized}
  end

  defp add_target_stats(target) do
    bullseye = get_bullseye_for_target(target.id)

    bullseye_trait_groups =
      case bullseye do
        nil -> []
        bullseye -> bullseye.trait_groups
      end

    bullseye_count = length(bullseye_trait_groups)
    outer_band_count = length(target.target_bands) - if(bullseye_count > 0, do: 1, else: 0)

    total_population =
      from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
        join: tb in TargetBand,
        on: tp.target_band_id == tb.id,
        where: tb.target_id == ^target.id,
        select: count(tp.id, :distinct)
      )
      |> Repo.one()

    is_frozen = is_frozen?(target.id)

    Map.merge(target, %{
      bullseye_trait_groups: bullseye_trait_groups,
      bullseye_trait_group_count: bullseye_count,
      outer_band_count: outer_band_count,
      total_population: total_population || 0,
      is_frozen: is_frozen
    })
  end

  defp get_target_id_for_band(band_id) do
    from(tb in TargetBand,
      where: tb.id == ^band_id,
      select: tb.target_id
    )
    |> Repo.one!()
  end

  defp sort_bands_by_trait_count(bands) do
    Enum.sort_by(bands, &length(&1.trait_groups), :desc)
  end

  def band_label(band, all_bands) do
    sorted_bands = sort_bands_by_trait_count(all_bands)

    if band.is_bullseye == "1" do
      "Bullseye"
    else
      index = Enum.find_index(sorted_bands, &(&1.id == band.id))

      if index do
        "Ring #{index}"
      else
        "Unknown"
      end
    end
  end

  @doc """
  Whether a target's band structure is locked against edits.

  Frozen if and only if a launched, still-active campaign references it, since
  bids are priced per band and re-shaping the rings under a running campaign
  would break billing integrity.

  This replaces the old rule of "any population row exists", which was only
  approximating the above. Two consequences, both intended: a content audience
  that drives discovery but no advertising stays editable, and a marketer target
  that was populated but never launched becomes editable again where it was
  previously stuck.
  """
  def is_frozen?(target_id) do
    from(c in Qlarius.Sponster.Campaigns.Campaign,
      where: c.target_id == ^target_id and not is_nil(c.launched_at) and is_nil(c.deactivated_at),
      limit: 1
    )
    |> Repo.exists?()
  end

  def depopulate_target(target_id) do
    from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id
    )
    |> Repo.delete_all()

    target = Repo.get!(Target, target_id)

    update_target(target, %{
      population_status: "not_populated",
      last_populated_at: nil
    })
  end

  def get_band_population_counts(target_id) do
    from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id,
      group_by: tb.id,
      select: {tb.id, count(tp.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Converts matching_tags_snapshot from list format to tuple format for display.

  The snapshot is stored as nested lists in JSONB, but display functions like
  `trait_card` expect tuples. This converts:

  `[[parent_id, name, order, [[child_id, value, order]]]]`

  to:

  `[{parent_id, name, order, [{child_id, value, order}]}]`

  Handles various snapshot formats including:
  - `%{matching_tags_snapshot: %{"tags" => [...]}}`
  - `%{"tags" => [...]}`
  - Old format maps (returns empty list)
  """
  def snapshot_to_tuples(%{matching_tags_snapshot: %{"tags" => tags}})
      when is_list(tags) do
    convert_tags_to_tuples(tags)
  end

  def snapshot_to_tuples(%{"tags" => tags}) when is_list(tags) do
    convert_tags_to_tuples(tags)
  end

  def snapshot_to_tuples(%{"parent_trait_id" => _, "trait_id" => _, "trait_name" => _}) do
    []
  end

  def snapshot_to_tuples(_), do: []

  defp convert_tags_to_tuples(tags) do
    Enum.map(tags, fn
      [parent_id, name, order, children] when is_list(children) ->
        {parent_id, name, order, Enum.map(children, &List.to_tuple/1)}

      %{"parent_trait_id" => _, "trait_id" => _, "trait_name" => _} ->
        nil

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
