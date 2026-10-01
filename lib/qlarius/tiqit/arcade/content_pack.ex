defmodule Qlarius.Tiqit.Arcade.ContentPack do
  @moduledoc """
  Creates or updates a content group and its pieces from one JSON pack.

  Used by the admin API (agent-built packs) and by `RssImporter`, which
  builds the same pack from a feed.

  Each piece is matched to an existing piece by `external_id` in the group,
  then `youtube_id` in the catalog, then `source_url` in the group. A match
  is refreshed (or left alone with `on_existing: "skip"`) and never
  duplicated. A YouTube match in a different group of the catalog is
  skipped so pieces are not moved between groups.

  Images are downloaded before the transaction. A failed image becomes a
  warning and does not fail the pack.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Arcade, Catalog, ContentGroup, ContentPiece, Creators, ImportImage}

  @modes ~w(create update)
  @refreshable [
    :title,
    :description,
    :date_published,
    :length,
    :youtube_id,
    :file_url,
    :media_type,
    :external_id,
    :season,
    :episode_number,
    :episode_type,
    :source_url
  ]

  @doc """
  Applies a pack. String keys, as decoded from JSON.

  Options (for internal callers such as `RssImporter`):

    * `:source_provider` - stored on new pieces and a new group
      (default `"api_pack"`; YouTube pieces always use `"youtube"`)
    * `:group_attrs` - extra group fields such as the feed settings

  Returns `{:ok, detail}` or `{:error, reason}`.
  """
  def apply(params, opts \\ []) when is_map(params) do
    mode = params["mode"]
    group_params = params["content_group"] || %{}
    pieces = params["pieces"]
    dry_run? = truthy?(params["dry_run"])
    on_existing = params["on_existing"] || "update"

    with :ok <- check_mode(mode),
         :ok <- check_on_existing(on_existing),
         :ok <- check_pieces_list(mode, pieces),
         {:ok, catalog} <- load_catalog(params["catalog_id"]),
         {:ok, group} <- load_group(mode, catalog, group_params),
         {:ok, group_attrs} <- group_attrs(mode, group_params, opts),
         {:ok, normalized} <- normalize_pieces(pieces, opts),
         normalized = drop_shared_art(normalized, group_params["image_url"]),
         plans <-
           plan_pieces(
             normalized,
             group,
             catalog,
             on_existing,
             Keyword.get(opts, :refresh_fields, @refreshable)
           ) do
      if dry_run? do
        {:ok, detail(group || preview_group(catalog, group_attrs), plans, [], true)}
      else
        write(mode, catalog, group, group_attrs, group_params, plans)
      end
    end
  end

  # ----- validation -----

  defp check_mode(mode) when mode in @modes, do: :ok
  defp check_mode(_), do: {:error, :invalid_pack_mode}

  defp check_on_existing(value) when value in ["update", "skip"], do: :ok
  defp check_on_existing(_), do: {:error, :invalid_on_existing}

  defp check_pieces_list("update", pieces) when is_list(pieces), do: :ok
  defp check_pieces_list("create", [_ | _]), do: :ok
  defp check_pieces_list(_, _), do: {:error, :empty_content_pack}

  defp load_catalog(id) do
    case integer(id) && Repo.get(Catalog, integer(id)) do
      %Catalog{} = catalog -> {:ok, Repo.preload(catalog, :creator)}
      _ -> {:error, :catalog_not_found}
    end
  end

  defp load_group("create", _catalog, %{"id" => id}) when not is_nil(id),
    do: {:error, :unexpected_content_group_id}

  defp load_group("create", _catalog, _params), do: {:ok, nil}

  defp load_group("update", catalog, params) do
    case integer(params["id"]) do
      nil ->
        {:error, :content_group_id_required}

      id ->
        case Repo.get(ContentGroup, id) do
          %ContentGroup{catalog_id: catalog_id} = group when catalog_id == catalog.id ->
            {:ok, %{group | catalog: catalog}}

          %ContentGroup{} ->
            {:error, :content_group_not_in_catalog}

          nil ->
            {:error, :not_found}
        end
    end
  end

  defp group_attrs(mode, params, opts) do
    attrs =
      %{
        title: blank_to_nil(params["title"]),
        description: blank_to_nil(params["description"]),
        source_url: blank_to_nil(params["source_url"])
      }
      |> Map.merge(Map.new(Keyword.get(opts, :group_attrs, %{})))
      |> reject_nils()

    attrs =
      if mode == "create",
        do: Map.put_new(attrs, :source_provider, Keyword.get(opts, :source_provider, "api_pack")),
        else: attrs

    cond do
      mode == "create" and is_nil(attrs[:title]) ->
        {:error, {:invalid_pack, [%{field: "content_group.title", message: "is required"}]}}

      true ->
        {:ok, Map.put(attrs, :image_url, blank_to_nil(params["image_url"]))}
    end
  end

  defp normalize_pieces(pieces, opts) do
    provider = Keyword.get(opts, :source_provider, "api_pack")

    results =
      pieces
      |> Enum.with_index()
      |> Enum.map(fn {params, index} -> normalize_piece(params, index, provider) end)

    errors =
      Enum.flat_map(results, fn
        {:error, errors} -> errors
        _ -> []
      end)

    normalized = for {:ok, piece} <- results, do: piece

    errors = errors ++ duplicate_external_id_errors(normalized)

    if errors == [], do: {:ok, normalized}, else: {:error, {:invalid_pack, errors}}
  end

  defp normalize_piece(params, index, provider) when is_map(params) do
    media = params["media"] || %{}

    {media_attrs, media_errors} =
      case media do
        %{"type" => "youtube", "youtube_id" => id} when is_binary(id) and id != "" ->
          {%{media_type: "youtube", youtube_id: String.trim(id)}, []}

        %{"type" => "youtube"} ->
          {%{}, ["media.youtube_id is required"]}

        %{"type" => "audio", "url" => url} when is_binary(url) and url != "" ->
          {%{media_type: "audio", file_url: String.trim(url)}, []}

        %{"type" => "audio"} ->
          {%{}, ["media.url is required"]}

        %{} when map_size(media) == 0 ->
          {%{}, ["media is required"]}

        _ ->
          {%{}, ["media.type must be youtube or audio"]}
      end

    {date, date_errors} = parse_date(params["date_published"])

    attrs =
      %{
        title: blank_to_nil(params["title"]),
        description: blank_to_nil(params["description"]),
        date_published: date,
        length: integer(params["length_seconds"]),
        external_id: blank_to_nil(params["external_id"]),
        season: integer(params["season"]),
        episode_number: integer(params["episode_number"]),
        episode_type: blank_to_nil(params["episode_type"]),
        source_url: blank_to_nil(params["source_url"]),
        display_order: integer(params["display_order"])
      }
      |> Map.merge(media_attrs)
      |> reject_nils()

    attrs =
      attrs
      |> Map.put(
        :source_provider,
        if(attrs[:media_type] == "youtube", do: "youtube", else: provider)
      )
      |> Map.put_new(:external_id, attrs[:youtube_id])
      |> reject_nils()

    changeset_errors =
      if media_errors == [] do
        %ContentPiece{}
        |> ContentPiece.import_changeset(attrs)
        |> changeset_messages()
      else
        []
      end

    case media_errors ++ date_errors ++ changeset_errors do
      [] ->
        {:ok, %{index: index, attrs: attrs, image_url: blank_to_nil(params["image_url"])}}

      messages ->
        {:error, Enum.map(messages, &%{index: index, message: &1})}
    end
  end

  defp normalize_piece(_params, index, _provider),
    do: {:error, [%{index: index, message: "piece must be an object"}]}

  # Piece art that repeats the group image or another piece's image is not
  # stored; those pieces fall back to the group image when displayed.
  defp drop_shared_art(pieces, group_image_url) do
    group_key = art_key(group_image_url)
    counts = pieces |> Enum.map(&art_key(&1.image_url)) |> Enum.frequencies()

    Enum.map(pieces, fn piece ->
      key = art_key(piece.image_url)

      if key && key != group_key && counts[key] == 1,
        do: piece,
        else: %{piece | image_url: nil}
    end)
  end

  defp art_key(url) when is_binary(url) and url != "" do
    uri = URI.parse(url)
    String.downcase("#{uri.host}#{uri.path}")
  end

  defp art_key(_), do: nil

  defp duplicate_external_id_errors(pieces) do
    pieces
    |> Enum.filter(& &1.attrs[:external_id])
    |> Enum.group_by(& &1.attrs.external_id)
    |> Enum.flat_map(fn
      {_id, [_]} ->
        []

      {id, [_ | rest]} ->
        Enum.map(rest, &%{index: &1.index, message: "external_id #{id} appears more than once"})
    end)
  end

  defp parse_date(nil), do: {nil, []}
  defp parse_date(""), do: {nil, []}

  defp parse_date(value) when is_binary(value) do
    with {:error, _} <- Date.from_iso8601(value),
         {:error, _} <- DateTime.from_iso8601(value) do
      {nil, ["date_published must be YYYY-MM-DD or ISO 8601"]}
    else
      {:ok, %Date{} = date} -> {date, []}
      {:ok, %DateTime{} = dt, _offset} -> {DateTime.to_date(dt), []}
    end
  end

  defp parse_date(_), do: {nil, ["date_published must be a string"]}

  defp changeset_messages(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
  end

  # ----- matching -----

  defp plan_pieces(pieces, group, catalog, on_existing, refresh_fields) do
    group_pieces = if group, do: group_pieces(group.id), else: []
    catalog_youtube = catalog_youtube_pieces(catalog.id)

    Enum.map(pieces, fn piece ->
      case match(piece.attrs, group, group_pieces, catalog_youtube) do
        nil ->
          Map.put(piece, :action, :create)

        {:other_group, existing} ->
          skip(piece, existing, "exists in another group of this catalog")

        %ContentPiece{archived_at: archived} = existing when not is_nil(archived) ->
          skip(piece, existing, "archived")

        existing when on_existing == "skip" ->
          skip(piece, existing, nil)

        existing ->
          plan_refresh(piece, existing, refresh_fields)
      end
    end)
  end

  defp skip(piece, existing, reason) do
    piece
    |> Map.put(:action, :skip)
    |> Map.put(:existing, existing)
    |> Map.put(:reason, reason)
  end

  defp plan_refresh(piece, existing, refresh_fields) do
    refresh_attrs = Map.take(piece.attrs, refresh_fields)
    changes = ContentPiece.import_changeset(existing, refresh_attrs).changes
    needs_image? = is_nil(existing.image) and is_binary(piece.image_url)

    action = if changes == %{} and not needs_image?, do: :unchanged, else: :update

    piece
    |> Map.put(:action, action)
    |> Map.put(:fields_changed?, changes != %{})
    |> Map.put(:existing, existing)
    |> Map.put(:refresh_attrs, refresh_attrs)
  end

  defp match(attrs, group, group_pieces, catalog_youtube) do
    group_id = group && group.id

    by_external =
      attrs[:external_id] && Enum.find(group_pieces, &(&1.external_id == attrs.external_id))

    by_youtube =
      attrs[:youtube_id] && Enum.find(catalog_youtube, &(&1.youtube_id == attrs.youtube_id))

    by_source =
      attrs[:source_url] && Enum.find(group_pieces, &(&1.source_url == attrs.source_url))

    cond do
      by_external -> by_external
      by_youtube && by_youtube.content_group_id == group_id -> by_youtube
      by_youtube -> {:other_group, by_youtube}
      by_source -> by_source
      true -> nil
    end
  end

  defp group_pieces(group_id) do
    Repo.all(from p in ContentPiece, where: p.content_group_id == ^group_id)
  end

  defp catalog_youtube_pieces(catalog_id) do
    Repo.all(
      from p in ContentPiece,
        join: g in ContentGroup,
        on: g.id == p.content_group_id,
        where: g.catalog_id == ^catalog_id and p.media_type == "youtube",
        where: not is_nil(p.youtube_id)
    )
  end

  # ----- writing -----

  defp write(mode, catalog, group, group_attrs, group_params, plans) do
    scope_group = group || %ContentGroup{catalog: catalog, catalog_id: catalog.id}

    {group_image, group_warnings} = maybe_group_image(mode, scope_group, group_attrs)
    {plans, piece_warnings} = download_piece_images(plans, scope_group)

    Repo.transaction(fn ->
      with {:ok, group} <-
             save_group(mode, catalog, group, group_attrs, group_params, group_image),
           {:ok, plans} <- save_pieces(group, plans) do
        detail(group, plans, group_warnings ++ piece_warnings, false)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp maybe_group_image(mode, group, %{image_url: url}) when is_binary(url) do
    if mode == "create" or is_nil(group.image) do
      case ImportImage.store(url, group, "group") do
        {:ok, filename} -> {filename, []}
        {:error, reason} -> {nil, ["content_group image: #{reason}"]}
      end
    else
      {nil, []}
    end
  end

  defp maybe_group_image(_mode, _group, _attrs), do: {nil, []}

  defp download_piece_images(plans, scope_group) do
    {plans, warnings} =
      Enum.map_reduce(plans, [], fn plan, warnings ->
        needs_image? =
          is_binary(plan.image_url) and
            (plan.action == :create or (plan.action == :update and is_nil(plan.existing.image)))

        if needs_image? do
          basename = "piece-#{plan.attrs[:external_id] || plan.index}"

          case ImportImage.store(plan.image_url, scope_group, basename) do
            {:ok, filename} ->
              {Map.put(plan, :image, filename), warnings}

            {:error, reason} ->
              {image_failed(plan), ["piece #{plan.index} image: #{reason}" | warnings]}
          end
        else
          {plan, warnings}
        end
      end)

    {plans, Enum.reverse(warnings)}
  end

  defp image_failed(%{action: :update, fields_changed?: false} = plan),
    do: %{plan | action: :unchanged}

  defp image_failed(plan), do: plan

  defp save_group(mode, catalog, group, attrs, _params, image) do
    attrs =
      attrs
      |> Map.delete(:image_url)
      |> then(fn attrs -> if image, do: Map.put(attrs, :image, image), else: attrs end)

    case mode do
      "create" ->
        %ContentGroup{catalog: catalog, catalog_id: catalog.id}
        |> ContentGroup.import_changeset(attrs)
        |> Repo.insert()

      "update" when map_size(attrs) == 0 ->
        {:ok, group}

      "update" ->
        group
        |> ContentGroup.import_changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, group} -> {:ok, %{group | catalog: catalog}}
      error -> error
    end
  end

  defp save_pieces(group, plans) do
    base_order = Creators.next_content_piece_display_order(group)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {saved, _next} =
      Enum.map_reduce(plans, base_order, fn plan, next_order ->
        case plan.action do
          :create ->
            {order, next_order} =
              case plan.attrs[:display_order] do
                nil -> {next_order, next_order + 1}
                order -> {order, next_order}
              end

            attrs =
              plan.attrs
              |> Map.put(:display_order, order)
              |> Map.put(:source_imported_at, now)
              |> Map.put_new(:date_published, Date.utc_today())
              |> put_image(plan)

            result =
              %ContentPiece{content_group_id: group.id, content_group: group}
              |> ContentPiece.import_changeset(attrs)
              |> Repo.insert()

            with {:ok, piece} <- result do
              Arcade.write_default_piece_tiqit_classes(piece)
            end

            {Map.put(plan, :result, result), next_order}

          :update ->
            attrs =
              plan.refresh_attrs
              |> Map.put(
                :source_provider,
                plan.existing.source_provider || plan.attrs.source_provider
              )
              |> put_image(plan)

            result =
              plan.existing
              |> ContentPiece.import_changeset(attrs)
              |> Repo.update()

            {Map.put(plan, :result, result), next_order}

          _unchanged_or_skip ->
            {Map.put(plan, :result, {:ok, plan.existing}), next_order}
        end
      end)

    case Enum.find(saved, &match?({:error, _}, &1.result)) do
      nil ->
        {:ok, saved}

      %{index: index, result: {:error, changeset}} ->
        {:error,
         {:invalid_pack, Enum.map(changeset_messages(changeset), &%{index: index, message: &1})}}
    end
  end

  defp put_image(attrs, %{image: image}) when is_binary(image), do: Map.put(attrs, :image, image)
  defp put_image(attrs, _plan), do: attrs

  # ----- output -----

  defp preview_group(catalog, attrs) do
    %ContentGroup{
      catalog_id: catalog.id,
      title: attrs[:title],
      description: attrs[:description],
      source_provider: attrs[:source_provider],
      source_url: attrs[:source_url],
      feed_url: attrs[:feed_url],
      feed_season: attrs[:feed_season],
      feed_episode_types: attrs[:feed_episode_types] || [],
      feed_auto_sync: attrs[:feed_auto_sync] || false
    }
  end

  defp detail(group, plans, warnings, dry_run?) do
    pieces = Enum.map(plans, &piece_detail/1)

    %{
      dry_run: dry_run?,
      content_group: group_json(group),
      pieces: pieces,
      counts: %{
        created: Enum.count(plans, &(&1.action == :create)),
        updated: Enum.count(plans, &(&1.action == :update)),
        unchanged: Enum.count(plans, &(&1.action == :unchanged)),
        skipped: Enum.count(plans, &(&1.action == :skip))
      },
      warnings: warnings
    }
  end

  defp piece_detail(plan) do
    piece =
      case plan do
        %{result: {:ok, piece}} -> piece
        %{existing: existing} -> existing
        _ -> nil
      end

    %{
      index: plan.index,
      status: status(plan.action),
      id: piece && piece.id,
      external_id: (piece && piece.external_id) || plan.attrs[:external_id],
      title: plan.attrs[:title],
      media_type: plan.attrs[:media_type]
    }
    |> then(fn detail ->
      if plan[:reason], do: Map.put(detail, :reason, plan.reason), else: detail
    end)
  end

  defp status(:create), do: "created"
  defp status(:update), do: "updated"
  defp status(:unchanged), do: "unchanged"
  defp status(:skip), do: "skipped"

  def group_json(%ContentGroup{} = group) do
    %{
      id: group.id,
      catalog_id: group.catalog_id,
      title: group.title,
      description: group.description,
      image: group.image,
      source_provider: group.source_provider,
      source_url: group.source_url,
      feed_url: group.feed_url,
      feed_season: group.feed_season,
      feed_episode_types: group.feed_episode_types,
      feed_auto_sync: group.feed_auto_sync,
      last_synced_at: group.last_synced_at
    }
  end

  # ----- helpers -----

  defp reject_nils(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp integer(_), do: nil

  defp truthy?(value), do: value in [true, "true", "1", 1]
end
