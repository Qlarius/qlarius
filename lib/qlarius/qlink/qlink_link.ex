defmodule Qlarius.Qlink.QlinkLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkSection
  alias Qlarius.Sponster.Recipient

  schema "qlink_links" do
    field :type, Ecto.Enum, values: [:standard, :embed, :social_feed, :insta_tip]
    field :title, :string
    field :description, :string
    field :url, :string
    field :thumbnail, :string
    field :embed_config, :map
    field :display_order, :integer
    field :is_visible, :boolean, default: true
    field :icon, :string
    field :click_count, :integer, default: 0
    field :show_tip_header, :boolean, default: true

    # Virtual fields for form handling
    field :embed_height, :integer, virtual: true
    field :embed_show_title, :boolean, virtual: true, default: true

    belongs_to :qlink_page, QlinkPage
    belongs_to :qlink_section, QlinkSection
    belongs_to :recipient, Recipient

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
      :qlink_section_id,
      :recipient_id,
      :show_tip_header,
      :embed_height,
      :embed_show_title
    ])
    |> validate_required([:type, :title, :display_order, :qlink_page_id])
    |> validate_url_unless_insta_tip()
    |> validate_length(:title, max: 200)
    |> validate_length(:description, max: 500)
    |> validate_url()
    |> foreign_key_constraint(:qlink_page_id)
    |> foreign_key_constraint(:qlink_section_id)
    |> foreign_key_constraint(:recipient_id)
  end

  defp validate_url_unless_insta_tip(changeset) do
    type = get_field(changeset, :type)

    if type == :insta_tip do
      changeset
    else
      validate_required(changeset, [:url])
    end
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

      same_domain_url?(url) ->
        %{platform: "iframe", url: url}

      true ->
        nil
    end
  end

  # Decides whether a URL should be treated as one of our own embedded
  # widgets (platform: "iframe"). Historically this only matched hosts
  # equal to the canonical `Endpoint.url()` host (i.e. `PHX_HOST`),
  # which became a bug when creators updated URLs to a different
  # Qadabra host: the entered URL's host no longer equalled PHX_HOST,
  # `same_domain_url?/1` returned false, `parse_embed_config/1`
  # returned nil, and the form's `detect_embed_type/2` fell back to
  # the previous `embed_config` — leaving `embed_config.url` stuck on
  # whatever host had been canonical at the original save time even
  # though the visible `url` field updated correctly. To fix that at
  # the root, accept any of the following as "our own widget":
  #
  #   1. Exact host match with `Endpoint.url()` (legacy behavior).
  #   2. Any URL whose path begins with `/widgets/arqade/` or
  #      `/widgets/arcade/` — an unambiguous arqade widget route that
  #      only our app serves, regardless of host.
  #   3. Host under any known Qadabra/Qlarius deployment family
  #      (`qadabra.app` + subdomains, `qlinkin.bio` + subdomains,
  #      `*.gigalixirapp.com`, `localhost`) — catches non-arqade
  #      widget URLs (e.g. `/widgets/insta_tip`) that cross hosts.
  defp same_domain_url?(url) do
    url_uri = URI.parse(url)

    base_host =
      QlariusWeb.Endpoint.url()
      |> URI.parse()
      |> Map.get(:host)

    cond do
      url_uri.host == base_host -> true
      arqade_widget_path?(url_uri.path) -> true
      known_deployment_host?(url_uri.host) -> true
      true -> false
    end
  end

  defp arqade_widget_path?(path) when is_binary(path) do
    String.starts_with?(path, "/widgets/arqade/") or
      String.starts_with?(path, "/widgets/arcade/")
  end

  defp arqade_widget_path?(_), do: false

  defp known_deployment_host?(host) when is_binary(host) do
    host == "qadabra.app" or String.ends_with?(host, ".qadabra.app") or
      host == "qlinkin.bio" or String.ends_with?(host, ".qlinkin.bio") or
      String.ends_with?(host, ".gigalixirapp.com") or
      host == "localhost"
  end

  defp known_deployment_host?(_), do: false

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
