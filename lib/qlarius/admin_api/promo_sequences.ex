defmodule Qlarius.AdminApi.PromoSequences do
  @moduledoc """
  Admin API for promotional banner sequences.

  Creates are idempotent on `api_ref`. A dry run validates and writes no row
  and no file.
  """

  alias Qlarius.AdminApi.Idempotent
  alias Qlarius.Sponster.PromoSequence
  alias Qlarius.Sponster.PromoSequences, as: Sequences

  @fields ~w(name global is_default max_height)

  def list(_params \\ %{}), do: Sequences.list_sequences()

  def fetch(id), do: Sequences.fetch(id)

  def create(params, opts) do
    with :ok <- bounce_ready?(params) do
      Idempotent.create(PromoSequence, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        extra_differences: &bounce_difference(&1, params),
        preview: &preview/1,
        preview_update: fn sequence, attrs, differences ->
          preview_write(sequence, attrs, differences)
        end,
        insert: fn _ -> insert(params) end,
        update: fn sequence, _attrs -> persist(sequence, params) end
      )
    end
  end

  def update(%PromoSequence{} = sequence, params, opts) do
    attrs = Map.take(params, @fields)

    differences =
      Map.merge(
        Idempotent.differences(sequence, params, @fields),
        bounce_difference(sequence, params)
      )

    with :ok <- bounce_ready?(params) do
      if opts[:dry_run] do
        preview_write(sequence, attrs, differences)
      else
        with {:ok, sequence} <- persist(sequence, params) do
          {:ok, %{result: "updated", record: sequence, differences: differences}}
        end
      end
    end
  end

  def delete(%PromoSequence{} = sequence, opts) do
    cond do
      sequence.is_default ->
        {:error, :default_sequence}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{promo_sequence: sequence.id}}}

      true ->
        with {:ok, _} <- Sequences.delete_sequence(sequence) do
          {:ok, %{result: "deleted", removes: %{promo_sequence: sequence.id}}}
        end
    end
  end

  def add_slide(%PromoSequence{} = sequence, params, opts) do
    track = params["track"]
    image = image_param(params)

    with :ok <- Sequences.validate_image(image),
         true <- track in Sequences.tracks() || {:error, :invalid_track} do
      if opts[:dry_run] do
        {:ok, %{result: "would_add", track: track, position: next_position(sequence, track)}}
      else
        with {:ok, filename} <- store_image(image),
             {:ok, slide} <-
               Sequences.add_slide(sequence, %{"track" => track, "image" => filename}) do
          {:ok, %{result: "added", slide: slide}}
        end
      end
    end
  end

  def replace_slide(%PromoSequence{} = sequence, slide_id, params, opts) do
    image = image_param(params)

    with {:ok, slide} <- Sequences.get_slide(sequence, slide_id),
         :ok <- Sequences.validate_image(image) do
      if opts[:dry_run] do
        {:ok, %{result: "would_replace", slide: slide}}
      else
        with {:ok, filename} <- store_image(image),
             {:ok, slide} <- Sequences.replace_slide(slide, filename) do
          {:ok, %{result: "replaced", slide: slide}}
        end
      end
    end
  end

  def delete_slide(%PromoSequence{} = sequence, slide_id, opts) do
    with {:ok, slide} <- Sequences.get_slide(sequence, slide_id) do
      if opts[:dry_run] do
        {:ok, %{result: "would_delete", removes: %{slide: slide.id}}}
      else
        with {:ok, _} <- Sequences.delete_slide(slide) do
          {:ok, %{result: "deleted", removes: %{slide: slide.id}}}
        end
      end
    end
  end

  def reorder(%PromoSequence{} = sequence, params, opts) do
    track = params["track"]
    ids = params["slide_ids"] || params["ids"]

    with :ok <- Sequences.check_reorder(sequence, track, ids) do
      if opts[:dry_run] do
        {:ok, %{result: "would_reorder", track: track, slide_ids: List.wrap(ids)}}
      else
        case Sequences.reorder(sequence, track, ids) do
          {:ok, sequence} -> {:ok, %{result: "reordered", record: sequence}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  defp preview(%{"name" => _} = params) do
    changeset = PromoSequence.changeset(%PromoSequence{}, Map.take(params, @fields))

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  defp preview(_params) do
    {:error, PromoSequence.changeset(%PromoSequence{}, %{})}
  end

  defp preview_write(sequence, attrs, differences) do
    changeset = PromoSequence.changeset(sequence, attrs)

    cond do
      not changeset.valid? ->
        {:error, changeset}

      clears_only_default?(sequence, attrs) ->
        {:error, :default_required}

      true ->
        {:ok, %{result: "would_update", record: sequence, differences: differences}}
    end
  end

  defp persist(sequence, params) do
    with {:ok, sequence} <- Sequences.update_sequence(sequence, Map.take(params, @fields)),
         {:ok, sequence} <- apply_bounce(sequence, params) do
      {:ok, Sequences.get_sequence!(sequence.id)}
    end
  end

  defp insert(params) do
    with {:ok, filename} <- stored_bounce(params) do
      params
      |> Map.take(@fields)
      |> put_bounce(filename)
      |> Sequences.create_sequence()
    end
  end

  defp apply_bounce(sequence, params) do
    cond do
      image_param(params, "bounce_image", "bounce_image_url") ->
        with {:ok, filename} <- stored_bounce(params) do
          Sequences.update_sequence(sequence, %{"bounce_image" => filename})
        end

      clear?(params) ->
        Sequences.update_sequence(sequence, %{"bounce_image" => nil})

      true ->
        {:ok, sequence}
    end
  end

  defp stored_bounce(params) do
    case image_param(params, "bounce_image", "bounce_image_url") do
      nil -> {:ok, nil}
      image -> store_image(image)
    end
  end

  defp put_bounce(attrs, nil), do: attrs
  defp put_bounce(attrs, filename), do: Map.put(attrs, "bounce_image", filename)

  defp store_image(%Plug.Upload{} = upload), do: Sequences.store_upload(upload)
  defp store_image(url) when is_binary(url), do: Sequences.store_remote(url)

  defp bounce_ready?(params) do
    case image_param(params, "bounce_image", "bounce_image_url") do
      nil -> :ok
      image -> Sequences.validate_image(image)
    end
  end

  defp bounce_difference(sequence, params) do
    case image_param(params, "bounce_image", "bounce_image_url") do
      %Plug.Upload{} = upload ->
        %{
          "bounce_image" => %{
            "current" => sequence.bounce_image,
            "requested" => upload.filename
          }
        }

      url when is_binary(url) ->
        %{
          "bounce_image" => %{
            "current" => Sequences.image_url(sequence.bounce_image),
            "requested" => url
          }
        }

      nil ->
        if clear?(params) and is_binary(sequence.bounce_image) do
          %{"bounce_image" => %{"current" => sequence.bounce_image, "requested" => nil}}
        else
          %{}
        end
    end
  end

  defp image_param(params, file_key \\ "image", url_key \\ "image_url") do
    case params[file_key] do
      %Plug.Upload{} = upload -> upload
      _ -> present(params[url_key])
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  defp clear?(params), do: params["clear_bounce_image"] in [true, "true", "1", 1]

  defp clears_only_default?(%PromoSequence{is_default: true}, attrs) do
    Map.has_key?(attrs, "is_default") and attrs["is_default"] not in [true, "true", "1", 1]
  end

  defp clears_only_default?(_sequence, _attrs), do: false

  defp next_position(sequence, track) do
    sequence.slides
    |> Enum.filter(&(&1.track == track))
    |> length()
    |> Kernel.+(1)
  end
end
