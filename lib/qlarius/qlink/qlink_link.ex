defmodule Qlarius.Qlink.QlinkLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkSection

  schema "qlink_links" do
    field :type, Ecto.Enum, values: [:standard, :embed, :social_feed]
    field :title, :string
    field :description, :string
    field :url, :string
    field :thumbnail, :string
    field :embed_config, :map
    field :display_order, :integer
    field :is_visible, :boolean, default: true
    field :icon, :string
    field :click_count, :integer, default: 0

    belongs_to :qlink_page, QlinkPage
    belongs_to :qlink_section, QlinkSection

    timestamps()
  end

  @doc false
  def changeset(qlink_link, attrs) do
    qlink_link
    |> cast(attrs, [
      :type,
      :title,
      :description,
      :url,
      :thumbnail,
      :embed_config,
      :display_order,
      :is_visible,
      :icon,
      :qlink_page_id,
      :qlink_section_id
    ])
    |> validate_required([:type, :title, :url, :display_order, :qlink_page_id])
    |> validate_length(:title, max: 200)
    |> validate_length(:description, max: 500)
    |> validate_url()
    |> foreign_key_constraint(:qlink_page_id)
    |> foreign_key_constraint(:qlink_section_id)
  end

  defp validate_url(changeset) do
    case get_field(changeset, :url) do
      nil ->
        changeset

      url ->
        uri = URI.parse(url)

        if uri.scheme in ["http", "https"] or String.starts_with?(url, "/") do
          changeset
        else
          add_error(changeset, :url, "must be a valid URL or path")
        end
    end
  end

  @doc """
  Parses embed configuration from URL for common platforms.
  """
  def parse_embed_config(url) do
    cond do
      youtube_id = parse_youtube_url(url) ->
        %{platform: "youtube", video_id: youtube_id}

      spotify_id = parse_spotify_url(url) ->
        %{platform: "spotify", content_id: spotify_id}

      tiktok_id = parse_tiktok_url(url) ->
        %{platform: "tiktok", video_id: tiktok_id}

      true ->
        nil
    end
  end

  defp parse_youtube_url(url) do
    cond do
      String.contains?(url, "youtube.com/watch") ->
        URI.parse(url).query
        |> URI.decode_query()
        |> Map.get("v")

      String.contains?(url, "youtu.be/") ->
        url
        |> String.split("youtu.be/")
        |> List.last()
        |> String.split("?")
        |> List.first()

      String.contains?(url, "youtube.com/shorts/") ->
        url
        |> String.split("youtube.com/shorts/")
        |> List.last()
        |> String.split("?")
        |> List.first()

      true ->
        nil
    end
  end

  defp parse_spotify_url(url) do
    if String.contains?(url, "spotify.com/") do
      url
      |> String.split("spotify.com/")
      |> List.last()
    end
  end

  defp parse_tiktok_url(url) do
    if String.contains?(url, "tiktok.com/") do
      url
      |> String.split("tiktok.com/")
      |> List.last()
    end
  end
end
