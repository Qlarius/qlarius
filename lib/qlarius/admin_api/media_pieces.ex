defmodule Qlarius.AdminApi.MediaPieces do
  @moduledoc """
  Media piece reads and writes for the admin campaign API.

  `ad_category_row_id` is resolved to an active ad category. Banner images come
  from a multipart upload or an HTTPS `image_url`, checked by `SafeFetch`.
  Video pieces are listed but not writable yet.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.{Idempotent, MediaPieceTypes, SafeFetch}
  alias Qlarius.Repo
  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.{AdCategories, MediaPiece}
  alias Qlarius.Sponster.Campaigns.MediaRun
  alias Qlarius.Sponster.Marketing

  @fields ~w(title body_copy display_url jump_url active duration marketer_id media_piece_type_id ad_category_id)
  @default_limit 100
  @max_limit 500

  def list(params) do
    from(p in MediaPiece, order_by: [desc: p.id], preload: [:ad_category, :media_piece_type])
    |> filter(:marketer_id, params["marketer_id"])
    |> filter_row(params["row_id"])
    |> filter_active(params["active"])
    |> filter_q(params["q"])
    |> filter_prefix(params["api_ref_prefix"])
    |> limit(^bound_limit(params["limit"]))
    |> Repo.all()
  end

  def fetch(id) do
    case Repo.get(MediaPiece, id) do
      nil -> {:error, :not_found}
      piece -> {:ok, Repo.preload(piece, [:ad_category, :media_piece_type])}
    end
  end

  def create(params, opts) do
    with {:ok, params} <- normalize(params),
         params = Map.put_new(params, "active", true),
         {:ok, image} <- prepare_image(params) do
      Idempotent.create(MediaPiece, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &owner_match?(&1, params),
        extra_differences: &image_difference(&1, image),
        preview: &preview(&1, image),
        preview_update: fn record, attrs, differences ->
          case MediaPiece.changeset(record, preview_attrs(attrs, image)) do
            %{valid?: true} ->
              {:ok, %{result: "would_update", record: record, differences: differences}}

            changeset ->
              {:error, changeset}
          end
        end,
        insert: &insert(&1, image),
        update: &apply_update(&1, &2, image)
      )
    end
  end

  def update(piece, params, opts) do
    with {:ok, params} <- normalize(params, piece),
         {:ok, image} <- prepare_image(params) do
      cond do
        Map.has_key?(params, "api_ref") and params["api_ref"] != piece.api_ref ->
          {:error, :api_ref_immutable}

        opts[:dry_run] ->
          preview_update(piece, params, image)

        true ->
          differences = differences(piece, params, image)
          attrs = Map.take(params, Map.keys(differences))

          with {:ok, attrs} <- put_stored_image(attrs, image),
               {:ok, updated} <- Marketing.update_media_piece(piece, attrs) do
            {:ok, %{result: "updated", record: preload(updated), differences: differences}}
          end
      end
    end
  end

  def delete(piece, opts) do
    dependents = dependents(piece.id)

    cond do
      Enum.any?(dependents, fn {_key, count} -> count > 0 end) ->
        {:error, {:has_dependents, dependents}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{media_piece: piece.id}}}

      true ->
        with {:ok, _} <- Marketing.delete_media_piece(piece) do
          {:ok, %{result: "deleted", removes: %{media_piece: piece.id}}}
        end
    end
  end

  def dependents(id) do
    %{
      media_runs: Repo.aggregate(from(r in MediaRun, where: r.media_piece_id == ^id), :count),
      ad_events: Repo.aggregate(from(e in AdEvent, where: e.media_piece_id == ^id), :count)
    }
  end

  defp normalize(params, existing \\ nil) do
    marketer_id = integer(params["marketer_id"] || (existing && existing.marketer_id))
    type_id = integer(params["media_piece_type_id"] || (existing && existing.media_piece_type_id))

    with :ok <- marketer_exists?(marketer_id),
         :ok <- writable_type?(type_id),
         {:ok, category_id} <- category_id(params, existing) do
      {:ok,
       params
       |> Map.put("marketer_id", marketer_id)
       |> Map.put("media_piece_type_id", type_id)
       |> Map.put("ad_category_id", category_id)
       |> Map.delete("ad_category_row_id")}
    end
  end

  defp marketer_exists?(id) when is_integer(id) do
    if Repo.get(Marketer, id), do: :ok, else: {:error, :marketer_not_found}
  end

  defp marketer_exists?(_), do: {:error, :marketer_not_found}

  defp writable_type?(id) when is_integer(id) do
    cond do
      MediaPieceTypes.writable?(id) and Repo.get(Qlarius.Sponster.Ads.MediaPieceType, id) ->
        :ok

      Repo.get(Qlarius.Sponster.Ads.MediaPieceType, id) ->
        {:error, :media_piece_type_not_writable}

      true ->
        {:error, :media_piece_type_not_found}
    end
  end

  defp writable_type?(_), do: {:error, :media_piece_type_not_found}

  defp category_id(%{"ad_category_row_id" => row_id}, _existing) when row_id not in [nil, ""] do
    case AdCategories.get_by_row_id(row_id) do
      nil -> {:error, {:not_found, row_id}}
      %{active: false, row_id: row_id} -> {:error, {:row_inactive, row_id}}
      category -> {:ok, category.id}
    end
  end

  defp category_id(_params, %{ad_category_id: id}) when is_integer(id), do: {:ok, id}
  defp category_id(_, _), do: {:error, :ad_category_required}

  defp prepare_image(%{"banner_image" => %Plug.Upload{} = upload}) do
    with {:ok, body} <- File.read(upload.path),
         {:ok, image} <- SafeFetch.fetch_bytes(body) do
      {:ok, image}
    else
      {:error, :image_type_rejected} -> {:error, :image_type_rejected}
      {:error, _} -> {:error, "The uploaded image could not be read"}
    end
  end

  defp prepare_image(%{"image_url" => url}) when is_binary(url) and url != "" do
    case SafeFetch.fetch(url) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, reason}
    end
  end

  defp prepare_image(_), do: {:ok, nil}

  defp preview(_params, nil), do: {:error, :image_required}

  defp preview(params, image) do
    attrs = Map.put(params, "banner_image", "dry-run.#{image.ext}")

    case MediaPiece.changeset(%MediaPiece{}, attrs) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      changeset -> {:error, changeset}
    end
  end

  defp insert(_params, nil), do: {:error, :image_required}

  defp insert(params, image) do
    with {:ok, attrs} <- put_stored_image(params, image),
         {:ok, piece} <- Marketing.create_media_piece(attrs) do
      {:ok, preload(piece)}
    end
  end

  defp apply_update(piece, attrs, image) do
    with {:ok, attrs} <- put_stored_image(attrs, image),
         {:ok, updated} <- Marketing.update_media_piece(piece, attrs) do
      {:ok, preload(updated)}
    end
  end

  defp preview_attrs(attrs, nil), do: attrs
  defp preview_attrs(attrs, image), do: Map.put(attrs, "banner_image", "dry-run.#{image.ext}")

  defp preview_update(piece, params, image) do
    attrs = params |> Map.take(@fields) |> preview_attrs(image)

    case MediaPiece.changeset(piece, attrs) do
      %{valid?: true} ->
        {:ok,
         %{result: "would_update", record: piece, differences: differences(piece, params, image)}}

      changeset ->
        {:error, changeset}
    end
  end

  defp differences(piece, params, image) do
    Idempotent.differences(piece, params, @fields)
    |> Map.merge(image_difference(piece, image))
  end

  defp image_difference(_piece, nil), do: %{}

  defp image_difference(piece, _image) do
    %{"banner_image" => %{"current" => piece.banner_image, "requested" => "replacement"}}
  end

  defp put_stored_image(attrs, nil), do: {:ok, attrs}

  defp put_stored_image(attrs, image) do
    path =
      Path.join(System.tmp_dir!(), "banner-#{System.unique_integer([:positive])}.#{image.ext}")

    File.write!(path, image.body)

    upload = %Plug.Upload{
      path: path,
      filename: "banner.#{image.ext}",
      content_type: image.content_type
    }

    {:ok, Map.put(attrs, "banner_image", upload)}
  end

  defp owner_match?(piece, params), do: piece.marketer_id == params["marketer_id"]

  defp preload(piece), do: Repo.preload(piece, [:ad_category, :media_piece_type], force: true)

  defp filter(query, field, value) when value not in [nil, ""] do
    where(query, [p], field(p, ^field) == ^integer(value))
  end

  defp filter(query, _field, _), do: query

  defp filter_row(query, row_id) when is_binary(row_id) and row_id != "" do
    case AdCategories.get_by_row_id(row_id) do
      nil -> where(query, [p], false)
      category -> where(query, [p], p.ad_category_id == ^category.id)
    end
  end

  defp filter_row(query, _), do: query

  defp filter_active(query, value) when value in [true, false, "true", "false"] do
    where(query, [p], p.active == ^truthy?(value))
  end

  defp filter_active(query, _), do: query

  defp filter_q(query, q) when is_binary(q) and q != "" do
    where(query, [p], ilike(p.title, ^"%#{q}%"))
  end

  defp filter_q(query, _), do: query

  defp filter_prefix(query, prefix) when is_binary(prefix) and prefix != "" do
    where(query, [p], like(p.api_ref, ^"#{prefix}%"))
  end

  defp filter_prefix(query, _), do: query

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil

  defp truthy?(value), do: value in [true, "true", "1"]

  defp bound_limit(value) do
    case integer(value) do
      n when is_integer(n) and n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end
end
