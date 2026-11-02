defmodule Qlarius.AdminApi.ContentPieces do
  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, Params, Prices, RemoteImage}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Arcade, ContentGroup, ContentPiece, Creators}

  @fields ~w(title description date_published length preview_length file_url youtube_id preview_url media_type external_id season episode_number episode_type display_order source_provider source_url exclude_from_catalog_access exclude_from_group_access)

  def list(%ContentGroup{} = group, params) do
    archived = params["archived"]

    ContentPiece
    |> where([p], p.content_group_id == ^group.id)
    |> archived_filter(archived)
    |> order_by([p], asc: p.display_order, asc: p.id)
    |> preload(content_group: :catalog)
    |> Repo.all()
  end

  def fetch(id) do
    case Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(ContentPiece, id) do
          nil -> {:error, :not_found}
          piece -> {:ok, Repo.preload(piece, content_group: :catalog)}
        end
    end
  end

  def create(%ContentGroup{} = group, params, opts) do
    params = Map.put_new(params, "date_published", Date.to_iso8601(Date.utc_today()))

    with :ok <- Prices.reject(params) do
      Idempotent.create(ContentPiece, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &(&1.content_group_id == group.id),
        preview: &preview/1,
        insert: fn _ -> insert(group, params) end,
        update: fn piece, _attrs -> save(piece, params) end
      )
    end
  end

  def update(%ContentPiece{} = piece, params, opts) do
    with :ok <- Prices.reject(params),
         :ok <- immutable?(piece, params),
         :ok <- RemoteImage.validate(params["image_url"]) do
      differences =
        piece
        |> Idempotent.differences(params, @fields)
        |> Map.merge(RemoteImage.difference(piece, params))

      if opts[:dry_run] do
        case ContentPiece.api_changeset(piece, Map.take(params, @fields)) do
          %{valid?: true} ->
            {:ok, %{result: "would_update", record: piece, differences: differences}}

          changeset ->
            {:error, changeset}
        end
      else
        with {:ok, updated} <- save(piece, params) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
      end
    end
  end

  def reorder(%ContentGroup{} = group, params) do
    ids =
      params["piece_ids"]
      |> List.wrap()
      |> Enum.map(&Params.integer/1)

    group = Repo.preload(group, :content_pieces)
    active = ContentGroup.active_content_pieces(group.content_pieces)
    by_id = Map.new(active, &{&1.id, &1})

    cond do
      Enum.any?(ids, &is_nil/1) ->
        {:error, :invalid_piece_set}

      length(ids) != length(active) or Enum.any?(ids, &(not Map.has_key?(by_id, &1))) ->
        {:error, :invalid_piece_set}

      dry_run?(params) ->
        {:ok, %{result: "would_reorder", piece_ids: ids}}

      true ->
        ordered = Enum.map(ids, &Map.fetch!(by_id, &1))

        case Creators.restripe_content_pieces(group, ordered) do
          {:ok, _group} -> {:ok, %{result: "reordered", piece_ids: ids}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def archive(%ContentPiece{} = piece, opts) do
    if opts[:dry_run] do
      {:ok, %{result: "would_archive", record: piece}}
    else
      case Creators.archive_content_piece(piece) do
        {:ok, piece} -> {:ok, %{result: "archived", record: piece}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def unarchive(%ContentPiece{} = piece, opts) do
    if opts[:dry_run] do
      {:ok, %{result: "would_unarchive", record: piece}}
    else
      case Creators.unarchive_content_piece(piece) do
        {:ok, piece} -> {:ok, %{result: "unarchived", record: piece}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def delete(%ContentPiece{} = piece, opts) do
    cond do
      not Creators.content_piece_hard_deletable?(piece) ->
        {:error, {:has_dependents, delete_dependents(piece)}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{content_piece: piece.id}}}

      true ->
        case Creators.delete_content_piece(piece) do
          {:ok, _} -> {:ok, %{result: "deleted", removes: %{content_piece: piece.id}}}
          {:error, :requires_archive} -> {:error, {:has_dependents, delete_dependents(piece)}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp delete_dependents(piece) do
    %{
      archived: if(piece.archived_at, do: 1, else: 0),
      tiqits: if(Creators.content_piece_hard_deletable?(piece), do: 0, else: 1)
    }
  end

  defp preview(params) do
    cs =
      ContentPiece.api_changeset(
        %ContentPiece{},
        Map.take(params, ["api_ref", "date_published" | @fields])
      )

    with :ok <- RemoteImage.validate(params["image_url"]),
         true <- cs.valid? || {:error, cs} do
      {:ok, Ecto.Changeset.apply_changes(cs)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert(group, params) do
    group = Repo.preload(group, :catalog)

    params =
      Map.put_new(params, "display_order", Creators.next_content_piece_display_order(group))

    Repo.transaction(fn ->
      with {:ok, piece} <-
             %ContentPiece{content_group_id: group.id, content_group: group}
             |> ContentPiece.api_changeset(
               Map.take(params, ["api_ref", "date_published" | @fields])
             )
             |> Repo.insert(),
           {:ok, piece} <- maybe_image(piece, params["image_url"]) do
        Arcade.write_default_piece_tiqit_classes(piece)
        piece
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp save(piece, params) do
    piece = Repo.preload(piece, content_group: :catalog)

    Repo.transaction(fn ->
      with {:ok, piece} <-
             piece |> ContentPiece.api_changeset(Map.take(params, @fields)) |> Repo.update(),
           {:ok, piece} <- maybe_image(piece, params["image_url"]) do
        piece
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp maybe_image(piece, url) when is_binary(url) and url != "" do
    piece = Repo.preload(piece, content_group: :catalog)
    RemoteImage.assign(piece, url, "piece-#{piece.id}")
  end

  defp maybe_image(piece, _), do: {:ok, piece}

  defp archived_filter(query, "only"), do: where(query, [p], not is_nil(p.archived_at))
  defp archived_filter(query, value) when value in [true, "true", "1", "all"], do: query
  defp archived_filter(query, _), do: where(query, [p], is_nil(p.archived_at))

  defp immutable?(piece, params) do
    if Map.has_key?(params, "api_ref") and params["api_ref"] != piece.api_ref do
      {:error, :api_ref_immutable}
    else
      :ok
    end
  end

  defp dry_run?(params), do: params["dry_run"] in [true, "true", "1"]
end
