defmodule Qlarius.Sponster.PromoSequences do
  @moduledoc """
  Promotional image sequences for the anonymous embed announcer.

  One sequence has two tracks, wide and narrow, a shared max height, and an
  optional bounce image. A missing sequence or an empty track keeps the three
  banners that used to be hardcoded on the bar. A missing bounce image keeps
  the quarter.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.RemoteImage
  alias Qlarius.Repo
  alias Qlarius.Sponster.{PromoSequence, PromoSequenceSlide}
  alias Qlarius.Tiqit.Arcade.ImportHttp
  alias QlariusWeb.Uploaders.PromoSequenceImage

  @banner_host "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com"
  @seed_keys [
    "uploads/recruiter_banners/DontReadThis_640.png",
    "uploads/recruiter_banners/LifeSponsored_640.png",
    "uploads/recruiter_banners/SellYourAttention_640.png"
  ]
  @tracks ["wide", "narrow"]
  @extensions ~w(.png .svg)
  @download_max_bytes 8 * 1024 * 1024

  def tracks, do: @tracks

  def fallback_slides do
    Enum.map(@seed_keys, &image_url/1)
  end

  def list_sequences do
    slides = slide_query()

    PromoSequence
    |> order_by([s], asc: s.name)
    |> preload(slides: ^slides)
    |> Repo.all()
  end

  def get_sequence!(id) do
    PromoSequence
    |> Repo.get!(id)
    |> Repo.preload([slides: slide_query()], force: true)
  end

  def fetch(id) do
    case integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(PromoSequence, id) do
          nil -> {:error, :not_found}
          sequence -> {:ok, Repo.preload(sequence, slides: slide_query())}
        end
    end
  end

  def default_id do
    Repo.one(from s in PromoSequence, where: s.is_default == true, select: s.id, limit: 1)
  end

  def choice_label(%PromoSequence{} = sequence) do
    marks = Enum.reject([sequence.global && "Global", sequence.is_default && "Default"], &(!&1))

    case marks do
      [] -> sequence.name
      marks -> sequence.name <> " · " <> Enum.join(marks, " · ")
    end
  end

  def change_sequence(%PromoSequence{} = sequence, attrs \\ %{}) do
    PromoSequence.changeset(sequence, attrs)
  end

  def create_sequence(attrs) do
    Repo.transaction(fn ->
      if truthy?(attrs["is_default"] || attrs[:is_default]) do
        clear_default()
      end

      case %PromoSequence{} |> PromoSequence.changeset(attrs) |> Repo.insert() do
        {:ok, sequence} -> Repo.preload(sequence, :slides)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_sequence(%PromoSequence{} = sequence, attrs) do
    with :ok <- keep_a_default(sequence, attrs) do
      Repo.transaction(fn ->
        if truthy?(attrs["is_default"] || attrs[:is_default]) do
          clear_default(sequence.id)
        end

        case sequence |> PromoSequence.changeset(attrs) |> Repo.update() do
          {:ok, updated} -> Repo.preload(updated, [slides: slide_query()], force: true)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  def delete_sequence(%PromoSequence{is_default: true}), do: {:error, :default_sequence}

  def delete_sequence(%PromoSequence{} = sequence) do
    case Repo.delete(sequence) do
      {:ok, _} -> {:ok, sequence}
      other -> other
    end
  end

  def add_slide(%PromoSequence{} = sequence, attrs) do
    track = attrs["track"] || attrs[:track]
    image = attrs["image"] || attrs[:image]

    with :ok <- track?(track),
         :ok <- image?(image) do
      %PromoSequenceSlide{}
      |> PromoSequenceSlide.changeset(%{
        "promo_sequence_id" => sequence.id,
        "track" => track,
        "position" => next_position(sequence.id, track),
        "image" => image
      })
      |> Repo.insert()
    end
  end

  def get_slide(%PromoSequence{} = sequence, id) do
    case integer(id) do
      nil ->
        {:error, :slide_not_found}

      id ->
        case Repo.get_by(PromoSequenceSlide, id: id, promo_sequence_id: sequence.id) do
          nil -> {:error, :slide_not_found}
          slide -> {:ok, slide}
        end
    end
  end

  def replace_slide(%PromoSequenceSlide{} = slide, image) do
    with :ok <- image?(image) do
      slide
      |> PromoSequenceSlide.changeset(%{"image" => image})
      |> Repo.update()
    end
  end

  def delete_slide(%PromoSequenceSlide{} = slide) do
    sequence_id = slide.promo_sequence_id
    track = slide.track

    Repo.transaction(fn ->
      case Repo.delete(slide) do
        {:ok, deleted} ->
          compact(sequence_id, track)
          deleted

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def check_reorder(%PromoSequence{} = sequence, track, ids) do
    ids = ids |> List.wrap() |> Enum.map(&integer/1)

    with :ok <- track?(track) do
      current = sequence.id |> slides_for(track) |> Enum.map(& &1.id) |> MapSet.new()

      if Enum.any?(ids, &is_nil/1) or MapSet.new(ids) != current or
           length(ids) != MapSet.size(current) do
        {:error, :reorder_mismatch}
      else
        :ok
      end
    end
  end

  def reorder(%PromoSequence{} = sequence, track, ids) do
    with :ok <- check_reorder(sequence, track, ids) do
      ids = ids |> List.wrap() |> Enum.map(&integer/1)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.transaction(fn ->
        Enum.with_index(ids, 1)
        |> Enum.each(fn {id, position} ->
          Repo.update_all(from(s in PromoSequenceSlide, where: s.id == ^id),
            set: [position: -position]
          )
        end)

        Enum.with_index(ids, 1)
        |> Enum.each(fn {id, position} ->
          Repo.update_all(from(s in PromoSequenceSlide, where: s.id == ^id),
            set: [position: position, updated_at: now]
          )
        end)
      end)

      {:ok, get_sequence!(sequence.id)}
    end
  end

  def store_upload(%Plug.Upload{} = upload) do
    ext = upload.filename |> Path.extname() |> String.downcase()

    with :ok <- extension_ok(ext),
         :ok <- svg_safe?(upload.path, ext) do
      filename = unique_name(upload.filename, ext)

      case PromoSequenceImage.store({%Plug.Upload{upload | filename: filename}, :promo}) do
        {:ok, stored} -> {:ok, stored}
        {:error, reason} -> {:error, {:upload_failed, :image, storage_message(reason)}}
      end
    end
  end

  def store_remote(url) do
    with :ok <- RemoteImage.validate(url),
         {:ok, ext} <- remote_extension(url),
         {:ok, %{body: body, content_type: content_type}} <-
           ImportHttp.get(url, max_bytes: @download_max_bytes),
         :ok <- svg_body_safe?(body, ext) do
      path = Path.join(System.tmp_dir!(), "promo-src-#{System.unique_integer([:positive])}#{ext}")

      try do
        File.write!(path, body)

        store_upload(%Plug.Upload{
          path: path,
          filename: url_name(url),
          content_type: content_type || content_type_for(ext)
        })
      after
        File.rm(path)
      end
    end
  end

  @doc """
  Checks a file or URL without writing it. Used by dry runs.
  """
  def validate_image(nil), do: {:error, :promo_image_required}
  def validate_image(""), do: {:error, :promo_image_required}

  def validate_image(%Plug.Upload{} = upload) do
    ext = upload.filename |> Path.extname() |> String.downcase()

    with :ok <- extension_ok(ext) do
      svg_safe?(upload.path, ext)
    end
  end

  def validate_image(url) when is_binary(url) do
    with :ok <- RemoteImage.validate(url),
         {:ok, _} <- remote_extension(url) do
      :ok
    end
  end

  def validate_image(_), do: {:error, :promo_image_required}

  def image_url(nil), do: nil
  def image_url(""), do: nil

  def image_url("uploads/recruiter_banners/" <> _ = key) do
    @banner_host <> "/" <> key
  end

  def image_url("uploads/" <> _ = key) do
    key |> Path.basename() |> image_url()
  end

  def image_url(filename) when is_binary(filename) do
    case PromoSequenceImage.url({filename, :promo}, :original) do
      nil -> nil
      url -> absolute_url(url)
    end
  end

  def preload(nil), do: nil

  def preload(recipient) do
    Repo.preload(recipient, promo_sequence: [slides: slide_query()])
  end

  def presentation(nil), do: fallback_presentation()
  def presentation(%{promo_sequence: nil}), do: fallback_presentation()

  def presentation(%{promo_sequence: %PromoSequence{} = sequence}) do
    slides = sequence.slides || []

    %{
      wide: track_urls(slides, "wide"),
      narrow: track_urls(slides, "narrow"),
      max_height: sequence.max_height || 80,
      bounce_url: image_url(sequence.bounce_image)
    }
  end

  def presentation(_), do: fallback_presentation()

  def fallback_presentation do
    %{wide: fallback_slides(), narrow: fallback_slides(), max_height: 80, bounce_url: nil}
  end

  def track_urls(slides, track) do
    urls =
      slides
      |> Enum.filter(&(&1.track == track))
      |> Enum.sort_by(& &1.position)
      |> Enum.map(&image_url(&1.image))
      |> Enum.reject(&is_nil/1)

    case urls do
      [] -> fallback_slides()
      urls -> urls
    end
  end

  defp slide_query do
    from(s in PromoSequenceSlide, order_by: [asc: s.track, asc: s.position])
  end

  defp slides_for(sequence_id, track) do
    Repo.all(
      from s in PromoSequenceSlide,
        where: s.promo_sequence_id == ^sequence_id and s.track == ^track,
        order_by: [asc: s.position]
    )
  end

  defp next_position(sequence_id, track) do
    current =
      Repo.one(
        from s in PromoSequenceSlide,
          where: s.promo_sequence_id == ^sequence_id and s.track == ^track,
          select: max(s.position)
      )

    (current || 0) + 1
  end

  defp compact(sequence_id, track) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    sequence_id
    |> slides_for(track)
    |> Enum.with_index(1)
    |> Enum.each(fn {slide, position} ->
      if slide.position != position do
        Repo.update_all(from(s in PromoSequenceSlide, where: s.id == ^slide.id),
          set: [position: -position]
        )
      end
    end)

    sequence_id
    |> slides_for(track)
    |> Enum.with_index(1)
    |> Enum.each(fn {slide, position} ->
      if slide.position != position do
        Repo.update_all(from(s in PromoSequenceSlide, where: s.id == ^slide.id),
          set: [position: position, updated_at: now]
        )
      end
    end)
  end

  defp clear_default(except_id \\ nil) do
    query = from(s in PromoSequence, where: s.is_default == true)
    query = if except_id, do: where(query, [s], s.id != ^except_id), else: query
    Repo.update_all(query, set: [is_default: false])
  end

  defp keep_a_default(%PromoSequence{is_default: true}, attrs) do
    if Map.has_key?(attrs, "is_default") or Map.has_key?(attrs, :is_default) do
      value =
        if Map.has_key?(attrs, "is_default"), do: attrs["is_default"], else: attrs[:is_default]

      if truthy?(value), do: :ok, else: {:error, :default_required}
    else
      :ok
    end
  end

  defp keep_a_default(_sequence, _attrs), do: :ok

  defp track?(track) when track in @tracks, do: :ok
  defp track?(_), do: {:error, :invalid_track}

  defp image?(image) when is_binary(image) and image != "", do: :ok
  defp image?(_), do: {:error, :promo_image_required}

  defp extension_ok(ext) when ext in @extensions, do: :ok
  defp extension_ok(_), do: {:error, {:upload_failed, :image, "Image must be a PNG or SVG"}}

  defp remote_extension(url) do
    ext =
      url |> URI.parse() |> Map.get(:path) |> to_string() |> Path.extname() |> String.downcase()

    if ext in @extensions do
      {:ok, ext}
    else
      {:error, {:upload_failed, :image, "Image must be a PNG or SVG"}}
    end
  end

  defp svg_safe?(_path, ext) when ext != ".svg", do: :ok

  defp svg_safe?(path, ".svg") do
    case File.read(path) do
      {:ok, body} ->
        svg_body_safe?(body, ".svg")

      {:error, reason} ->
        {:error, {:upload_failed, :image, "could not read image: #{inspect(reason)}"}}
    end
  end

  defp svg_body_safe?(_body, ext) when ext != ".svg", do: :ok

  defp svg_body_safe?(body, ".svg") do
    down = String.downcase(body)

    if String.contains?(down, "<script") or String.contains?(down, "javascript:") do
      {:error, {:upload_failed, :image, "SVG cannot contain script"}}
    else
      :ok
    end
  end

  defp unique_name(original, ext) do
    root =
      original
      |> url_name()
      |> Path.rootname()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")
      |> case do
        "" -> "promo"
        root -> String.slice(root, 0, 80)
      end

    token = Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    "#{root}-#{token}#{ext}"
  end

  defp url_name(name) when is_binary(name) do
    name |> URI.parse() |> Map.get(:path) |> to_string() |> Path.basename()
  end

  defp content_type_for(".svg"), do: "image/svg+xml"
  defp content_type_for(_), do: "image/png"

  defp storage_message(:invalid_file), do: "Image must be a PNG or SVG"
  defp storage_message(reason) when is_binary(reason), do: reason
  defp storage_message(reason) when is_exception(reason), do: Exception.message(reason)
  defp storage_message(reason), do: inspect(reason)

  defp absolute_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] ->
        url

      _ ->
        host = Application.get_env(:waffle, :asset_host) || ""
        path = if String.starts_with?(url, "/"), do: url, else: "/" <> url
        host <> path
    end
  end

  defp truthy?(value) when value in [true, "true", "1", 1], do: true
  defp truthy?(_), do: false

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
