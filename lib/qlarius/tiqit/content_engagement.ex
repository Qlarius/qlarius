defmodule Qlarius.Tiqit.ContentEngagement do
  @moduledoc """
  Records discovery actions and daily impression counters.

  All writes go through `record/1`, `record_impression/3`, or
  `record_purchase/4` so FK and `_ss` values are derived from the same
  loaded struct (or the same integer id) and cannot disagree.

  `target_band_id_ss IS NULL` is the organic discriminator. A deleted
  band reads as `target_band_id IS NULL AND target_band_id_ss IS NOT NULL`.
  """

  import Ecto.Query

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Repo
  alias Qlarius.Tiqit.{ContentEngagementEvent, ContentImpressionDaily}
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, Tiqit, TiqitClass}
  alias Qlarius.Creators.Creator
  alias Qlarius.Sponster.Campaigns.{Target, TargetBand}
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader

  @doc """
  Writes one action event. `attrs` must include `:type` and `:surface`.
  Optional loaded structs: `:piece`, `:group`, `:catalog`, `:creator`,
  `:band`, `:target`, `:tiqit`, plus `:me_file_id`, `:session_id`,
  `:snapshot`, `:tier`, `:population_count`, `:boost_level`,
  `:rank_position`, integer `:target_band_id` / `:target_id`, and
  `:from_click` to copy last-touch attribution for fields not set here.
  """
  def record(attrs) when is_map(attrs) do
    piece = Map.get(attrs, :piece)
    group = Map.get(attrs, :group) || (piece && piece.content_group)
    catalog = Map.get(attrs, :catalog) || (group && group.catalog)
    creator = Map.get(attrs, :creator) || (catalog && catalog.creator)
    band = Map.get(attrs, :band)
    target = Map.get(attrs, :target) || (band && band.target)
    tiqit = Map.get(attrs, :tiqit)
    from_click = Map.get(attrs, :from_click)

    event_attrs =
      %{
        type: attrs.type,
        surface: attrs.surface,
        session_id: Map.get(attrs, :session_id),
        matching_tags_snapshot: Map.get(attrs, :snapshot),
        tier: Map.get(attrs, :tier),
        population_count: Map.get(attrs, :population_count),
        boost_level: Map.get(attrs, :boost_level),
        rank_position: Map.get(attrs, :rank_position),
        me_file_id: Map.get(attrs, :me_file_id)
      }
      |> put_id_pair(:target_band, band, Map.get(attrs, :target_band_id))
      |> put_id_pair(:target, target, Map.get(attrs, :target_id))
      |> put_id_pair(:content_piece, piece, nil)
      |> put_id_pair(:content_group, group, nil)
      |> put_id_pair(:catalog, catalog, nil)
      |> put_id_pair(:creator, creator, nil)
      |> put_id_pair(:tiqit, tiqit, nil)
      |> maybe_put_title(piece)
      |> maybe_put_creator_name(creator)
      |> maybe_copy_attribution(from_click)

    %ContentEngagementEvent{}
    |> ContentEngagementEvent.changeset(event_attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, event} ->
        if event.type == :click and event.content_piece_id do
          bump_daily(event.content_piece_id, event.surface, event.target_band_id, :clicks)
        end

      _ ->
        :ok
    end)
  end

  def record_impression(piece, surface, band \\ nil)

  def record_impression(%ContentPiece{} = piece, surface, %TargetBand{id: id}) do
    bump_daily(piece.id, surface, id, :impressions)
    :ok
  end

  def record_impression(%ContentPiece{} = piece, surface, band_id) when is_integer(band_id) do
    bump_daily(piece.id, surface, band_id, :impressions)
    :ok
  end

  def record_impression(%ContentPiece{} = piece, surface, _) do
    bump_daily(piece.id, surface, nil, :impressions)
    :ok
  end

  @doc """
  Last-touch attribution: most recent click or content_open for this
  me_file and piece.
  """
  def last_click(me_file_id, piece_id) do
    from(e in ContentEngagementEvent,
      where:
        e.me_file_id == ^me_file_id and e.content_piece_id == ^piece_id and
          e.type in [:click, :content_open],
      order_by: [desc: e.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Writes a `:tiqit_purchase` event. Explicit `:discovery_surface` /
  `:target_band_id` in `opts` win; otherwise attribution is copied from
  the most recent click or content_open for this me_file and piece.
  """
  def record_purchase(%Scope{} = scope, %Tiqit{} = tiqit, %TiqitClass{} = tiqit_class, opts \\ []) do
    piece = loaded(tiqit_class.content_piece)
    group = loaded(tiqit_class.content_group) || (piece && loaded(piece.content_group))
    catalog = loaded(tiqit_class.catalog) || (group && loaded(group.catalog))
    creator = catalog && loaded(catalog.creator)
    me_file_id = me_file_id(scope)

    click =
      if piece && me_file_id && is_nil(Keyword.get(opts, :target_band_id)) do
        last_click(me_file_id, piece.id)
      end

    surface =
      Keyword.get(opts, :discovery_surface) ||
        (click && click.surface) ||
        :direct

    record(%{
      type: :tiqit_purchase,
      surface: surface,
      piece: piece,
      group: group,
      catalog: catalog,
      creator: creator,
      tiqit: tiqit,
      me_file_id: me_file_id,
      target_band_id: Keyword.get(opts, :target_band_id),
      from_click: click
    })
  end

  def anonymize_for_me_file(me_file_id) do
    from(e in ContentEngagementEvent, where: e.me_file_id == ^me_file_id)
    |> Repo.update_all(
      set: [me_file_id: nil, matching_tags_snapshot: nil, session_id: nil]
    )
  end

  def summary_for_creator(creator_id) do
    from(e in ContentEngagementEvent,
      where: e.creator_id_ss == ^creator_id,
      group_by: e.type,
      select: {e.type, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def recommended_vs_organic(creator_id) do
    from(e in ContentEngagementEvent,
      where: e.creator_id_ss == ^creator_id,
      select: %{
        recommended: filter(count(e.id), not is_nil(e.target_band_id_ss)),
        organic: filter(count(e.id), is_nil(e.target_band_id_ss))
      }
    )
    |> Repo.one()
    |> case do
      nil -> %{recommended: 0, organic: 0}
      row -> row
    end
  end

  @doc """
  Aggregate funnel for a creator. Impressions and clicks come from the
  daily counters; purchases and revenue come from events and creator
  ledger credits (`meta_1 = "Tiqit Sale"`).
  """
  def funnel_for_creator(creator_id) do
    impression_row =
      from(d in ContentImpressionDaily,
        join: p in ContentPiece,
        on: p.id == d.content_piece_id,
        join: g in ContentGroup,
        on: g.id == p.content_group_id,
        join: c in Catalog,
        on: c.id == g.catalog_id,
        where: c.creator_id == ^creator_id,
        select: %{
          impressions: coalesce(sum(d.impressions), 0),
          clicks: coalesce(sum(d.clicks), 0)
        }
      )
      |> Repo.one()

    purchases =
      from(e in ContentEngagementEvent,
        where: e.creator_id_ss == ^creator_id and e.type == :tiqit_purchase,
        select: count(e.id)
      )
      |> Repo.one()

    revenue =
      from(e in LedgerEntry,
        join: h in LedgerHeader,
        on: h.id == e.ledger_header_id,
        where: h.creator_id == ^creator_id and e.meta_1 == "Tiqit Sale",
        select: coalesce(sum(e.amt), 0)
      )
      |> Repo.one()

    %{
      impressions: impression_row.impressions || 0,
      clicks: impression_row.clicks || 0,
      purchases: purchases || 0,
      revenue: revenue || Decimal.new(0)
    }
  end

  @doc """
  Per-audience conversion. Organic rows (`target_id_ss` nil) are omitted.
  """
  def per_audience_conversion(creator_id) do
    from(e in ContentEngagementEvent,
      left_join: t in Target,
      on: t.id == e.target_id,
      where: e.creator_id_ss == ^creator_id and not is_nil(e.target_id_ss),
      group_by: [e.target_id_ss, t.title],
      select: %{
        target_id: e.target_id_ss,
        title: t.title,
        clicks: filter(count(e.id), e.type == :click),
        purchases: filter(count(e.id), e.type == :tiqit_purchase)
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      title = row.title || "Audience ##{row.target_id}"
      rate = conversion_rate(row.purchases, row.clicks)
      Map.merge(row, %{title: title, conversion: rate})
    end)
  end

  def record_feed_impressions(%{picked: picked, more: more}) do
    Enum.each(picked, &record_card_impression(&1, :picked_for_you))
    Enum.each(more, &record_card_impression(&1, :more_from_creators))
    :ok
  end

  def record_discovery_click(scope, attrs) when is_map(attrs) do
    record(Map.put(attrs, :type, :click) |> Map.put(:me_file_id, me_file_id(scope)))
  end

  def record_content_open(scope, attrs) when is_map(attrs) do
    record(Map.put(attrs, :type, :content_open) |> Map.put(:me_file_id, me_file_id(scope)))
  end

  def record_preview_start(scope, attrs) when is_map(attrs) do
    record(Map.put(attrs, :type, :preview_start) |> Map.put(:me_file_id, me_file_id(scope)))
  end

  defp record_card_impression(%{kind: :piece, item: piece, resolve: resolve}, surface) do
    record_impression(piece, surface, band_id_from(resolve))
  end

  defp record_card_impression(%{kind: :group, item: group, resolve: resolve}, surface) do
    band_id = band_id_from(resolve)

    (group.content_pieces || [])
    |> Enum.filter(&is_nil(&1.archived_at))
    |> Enum.each(&record_impression(&1, surface, band_id))
  end

  defp record_card_impression(_, _), do: :ok

  defp band_id_from(%{boost_match: %{band_id: id}}) when is_integer(id), do: id
  defp band_id_from(_), do: nil

  defp me_file_id(%Scope{user: %{me_file: %{id: id}}}), do: id
  defp me_file_id(%Scope{user: %{me_file_id: id}}) when is_integer(id), do: id

  defp me_file_id(%Scope{user: %{id: user_id}}) do
    case Accounts.get_me_file_by_user_id(user_id) do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp me_file_id(_), do: nil

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(other), do: other

  defp conversion_rate(purchases, clicks) when clicks > 0 do
    Decimal.div(Decimal.new(purchases), Decimal.new(clicks))
  end

  defp conversion_rate(_, _), do: Decimal.new(0)

  defp put_id_pair(attrs, field, %{id: id}, _), do: put_pair(attrs, field, %{id: id})
  defp put_id_pair(attrs, field, _, id) when is_integer(id), do: put_pair(attrs, field, %{id: id})
  defp put_id_pair(attrs, _, _, _), do: attrs

  defp put_pair(attrs, field, %{id: id}) do
    attrs
    |> Map.put(:"#{field}_id", id)
    |> Map.put(:"#{field}_id_ss", id)
  end

  defp maybe_put_title(attrs, %ContentPiece{title: title}),
    do: Map.put(attrs, :content_piece_title_ss, title)

  defp maybe_put_title(attrs, _), do: attrs

  defp maybe_put_creator_name(attrs, %Creator{name: name}),
    do: Map.put(attrs, :creator_name_ss, name)

  defp maybe_put_creator_name(attrs, _), do: attrs

  defp maybe_copy_attribution(attrs, nil), do: attrs

  defp maybe_copy_attribution(attrs, click) do
    attrs
    |> put_if_blank(:target_band_id, click.target_band_id)
    |> put_if_blank(:target_band_id_ss, click.target_band_id_ss)
    |> put_if_blank(:target_id, click.target_id)
    |> put_if_blank(:target_id_ss, click.target_id_ss)
    |> put_if_blank(:matching_tags_snapshot, click.matching_tags_snapshot)
    |> put_if_blank(:tier, click.tier)
    |> put_if_blank(:population_count, click.population_count)
    |> put_if_blank(:boost_level, click.boost_level)
  end

  defp put_if_blank(attrs, key, value) do
    if is_nil(Map.get(attrs, key)) and not is_nil(value) do
      Map.put(attrs, key, value)
    else
      attrs
    end
  end

  defp bump_daily(piece_id, surface, band_id, field) do
    surface = to_string(surface)
    today = Date.utc_today()

    q =
      from(d in ContentImpressionDaily,
        where: d.date == ^today and d.content_piece_id == ^piece_id and d.surface == ^surface
      )

    q =
      if band_id do
        where(q, [d], d.target_band_id == ^band_id)
      else
        where(q, [d], is_nil(d.target_band_id))
      end

    case Repo.update_all(q, inc: [{field, 1}]) do
      {0, _} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.insert(%ContentImpressionDaily{
          date: today,
          content_piece_id: piece_id,
          surface: surface,
          target_band_id: band_id,
          impressions: if(field == :impressions, do: 1, else: 0),
          clicks: if(field == :clicks, do: 1, else: 0),
          inserted_at: now
        })

      _ ->
        :ok
    end
  end
end
