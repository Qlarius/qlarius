defmodule Qlarius.Qlink.LinkInBioImporter do
  @moduledoc """
  Fetches and imports public link-in-bio pages into draft Qlink pages.

  Supported platforms: Linktree, Beacons, plus a generic HTML fallback.
  """

  require Logger

  alias Ecto.Multi
  alias Qlarius.Creators.RecipientProvisioning
  alias Qlarius.Qlink
  alias Qlarius.Qlink.LinkInBio.{Beacons, Draft, Generic, Linktree}
  alias Qlarius.Qlink.QlinkLink
  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Repo
  alias QlariusWeb.Uploaders.CreatorImage

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  @doc """
  Detect platform from URL host.
  """
  def detect_platform(url) when is_binary(url) do
    host =
      url
      |> URI.parse()
      |> Map.get(:host)
      |> case do
        nil -> ""
        h -> h |> String.downcase() |> String.replace_prefix("www.", "")
      end

    cond do
      host in ["linktr.ee", "linktree.com"] or String.ends_with?(host, ".linktr.ee") ->
        :linktree

      host in ["beacons.ai", "beacons.page"] or String.ends_with?(host, ".beacons.ai") ->
        :beacons

      true ->
        :generic
    end
  end

  @doc """
  Normalize user-entered URL (add https if missing).
  """
  def normalize_url(url) when is_binary(url) do
    url = String.trim(url)

    cond do
      url == "" ->
        {:error, :empty_url}

      String.match?(url, ~r/^https?:\/\//i) ->
        {:ok, url}

      true ->
        {:ok, "https://" <> url}
    end
  end

  def normalize_url(_), do: {:error, :empty_url}

  @doc """
  Fetch the page and return a `%Draft{}` for review.
  """
  def fetch_preview(url) when is_binary(url) do
    with {:ok, url} <- normalize_url(url),
         {:ok, html} <- fetch_html(url) do
      platform = detect_platform(url)

      draft =
        case platform do
          :linktree -> Linktree.parse(html, url)
          :beacons -> Beacons.parse(html, url)
          :generic -> Generic.parse(html, url)
        end

      draft = ensure_alias(draft)
      {:ok, draft}
    end
  end

  @doc """
  Commit a reviewed draft into a new unpublished Qlink page for `creator`.

  `opts`:
  - `:alias` — override draft.suggested_alias
  - `:title` — override title
  - `:bio_text` — override bio
  - `:sections` — reviewed sections (with include? flags)
  """
  def import!(%Draft{} = draft, creator, opts \\ []) do
    creator = Repo.preload(creator, [:recipient])

    with {:ok, recipient} <- RecipientProvisioning.ensure_recipient_for_creator(creator) do
      do_import(draft, creator, recipient, opts)
    end
  end

  defp do_import(draft, creator, recipient, opts) do
    alias_ =
      opts
      |> Keyword.get(:alias, draft.suggested_alias)
      |> Draft.sanitize_alias()
      |> unique_alias()

    title = Keyword.get(opts, :title) || draft.title || alias_ || "Imported page"
    bio = Keyword.get(opts, :bio_text, draft.bio_text)
    sections = Keyword.get(opts, :sections, draft.sections) || []
    social_links = draft.social_links || %{}

    Multi.new()
    |> Multi.run(:page, fn _repo, _ ->
      Qlink.create_page(%{
        "alias" => alias_,
        "slug" => alias_,
        "title" => String.slice(to_string(title), 0, 100),
        "bio_text" => bio && String.slice(to_string(bio), 0, 500),
        "creator_id" => creator.id,
        "recipient_id" => recipient.id,
        "show_insta_tip" => true,
        "is_published" => false,
        "social_links" => social_links
      })
    end)
    |> Multi.run(:avatar, fn _repo, %{page: page} ->
      case rehost_avatar(draft.avatar_url, page) do
        {:ok, filename} when is_binary(filename) ->
          Qlink.update_page(page, %{profile_photo: filename})

        {:ok, nil} ->
          {:ok, page}

        {:error, reason} ->
          Logger.warning("Link-in-bio avatar rehost failed: #{inspect(reason)}")
          {:ok, page}
      end
    end)
    |> Multi.run(:content, fn _repo, %{avatar: page} ->
      create_sections_and_links(page, sections, recipient.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{avatar: page}} ->
        {:ok, Qlink.get_page!(page.id)}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp fetch_html(url) do
    case Req.get(url,
           headers: [{"user-agent", @user_agent}, {"accept", "text/html"}],
           redirect: true,
           max_redirects: 5,
           receive_timeout: 20_000
         ) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, {:fetch_failed, Exception.message(exception)}}
    end
  end

  defp ensure_alias(%Draft{suggested_alias: alias_} = draft) do
    alias_ =
      alias_
      |> Draft.sanitize_alias()
      |> case do
        nil -> "import-#{System.unique_integer([:positive])}"
        a -> a
      end

    %{draft | suggested_alias: alias_}
  end

  defp unique_alias(nil), do: unique_alias("import")

  defp unique_alias(base) do
    base = Draft.sanitize_alias(base) || "import"

    if Qlink.alias_available?(base) and String.length(base) >= 3 do
      base
    else
      Enum.find_value(1..50, fn n ->
        candidate = String.slice("#{base}-#{n}", 0, 30)
        if Qlink.alias_available?(candidate), do: candidate
      end) || "import-#{System.unique_integer([:positive])}"
    end
  end

  defp rehost_avatar(nil, _page), do: {:ok, nil}
  defp rehost_avatar("", _page), do: {:ok, nil}

  defp rehost_avatar(url, %QlinkPage{} = page) do
    case download_image(url) do
      {:ok, tmp_path, filename, content_type} ->
        upload = %Plug.Upload{path: tmp_path, filename: filename, content_type: content_type}
        result = CreatorImage.store({upload, page})
        File.rm(tmp_path)

        case result do
          {:ok, stored} -> {:ok, stored}
          other -> {:error, other}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp rehost_thumbnail(nil, _page), do: {:ok, nil}
  defp rehost_thumbnail("", _page), do: {:ok, nil}

  defp rehost_thumbnail(url, %QlinkPage{} = page) do
    case download_image(url) do
      {:ok, tmp_path, filename, content_type} ->
        upload = %Plug.Upload{path: tmp_path, filename: filename, content_type: content_type}

        case CreatorImage.store({upload, page}) do
          {:ok, stored} ->
            File.rm(tmp_path)
            {:ok, stored}

          other ->
            File.rm(tmp_path)
            Logger.warning("Thumbnail store failed, keeping remote URL: #{inspect(other)}")
            {:ok, url}
        end

      {:error, _} ->
        {:ok, url}
    end
  end

  defp download_image(url) do
    case Req.get(url,
           headers: [{"user-agent", @user_agent}],
           redirect: true,
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: 200, body: body, headers: headers}} when is_binary(body) ->
        ext = image_extension(url, headers)
        filename = "import-#{:erlang.unique_integer([:positive])}#{ext}"
        tmp_path = Path.join(System.tmp_dir!(), filename)
        File.write!(tmp_path, body)
        {:ok, tmp_path, filename, content_type_for(ext)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp image_extension(url, headers) do
    from_path =
      case Path.extname(URI.parse(url).path || "") |> String.downcase() do
        ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".webp"] -> ext
        _ -> nil
      end

    from_path ||
      case get_header(headers, "content-type") do
        "image/png" <> _ -> ".png"
        "image/gif" <> _ -> ".gif"
        "image/webp" <> _ -> ".webp"
        _ -> ".jpg"
      end
  end

  defp get_header(headers, name) do
    Enum.find_value(headers, fn
      {k, v} -> if String.downcase(to_string(k)) == name, do: to_string(v)
      _ -> nil
    end)
  end

  defp content_type_for(".png"), do: "image/png"
  defp content_type_for(".gif"), do: "image/gif"
  defp content_type_for(".webp"), do: "image/webp"
  defp content_type_for(_), do: "image/jpeg"

  defp create_sections_and_links(page, sections, recipient_id) do
    {order, _} =
      Enum.reduce(sections, {0, 0}, fn section, {link_order, section_order} ->
        included = Enum.filter(section.links || [], & &1[:include?])

        if included == [] do
          {link_order, section_order}
        else
          section_id =
            if section[:title] && String.trim(to_string(section.title)) != "" do
              case Qlink.create_section(%{
                     "qlink_page_id" => page.id,
                     "title" => String.slice(to_string(section.title), 0, 100),
                     "display_order" => section_order
                   }) do
                {:ok, s} -> s.id
                _ -> nil
              end
            else
              nil
            end

          link_order =
            Enum.reduce(included, link_order, fn link, ord ->
              insert_content_link(page, link, ord, section_id)
              ord + 1
            end)

          next_section_order = if section_id, do: section_order + 1, else: section_order
          {link_order, next_section_order}
        end
      end)

    # Default tip jar at the bottom
    _ =
      Qlink.create_link(%{
        "qlink_page_id" => page.id,
        "type" => "insta_tip",
        "title" => "Tip Jar",
        "display_order" => order,
        "is_visible" => true,
        "recipient_id" => recipient_id,
        "show_tip_header" => true
      })

    {:ok, page}
  end

  defp insert_content_link(page, link, order, section_id) do
    url = link[:url] || link["url"]
    title = link[:title] || link["title"] || "Link"
    thumb_remote = link[:thumbnail_url] || link["thumbnail_url"]

    {:ok, thumb} = rehost_thumbnail(thumb_remote, page)

    embed_config = if is_binary(url), do: QlinkLink.parse_embed_config(url)

    {type, embed_config} =
      if embed_config do
        {:embed, embed_config}
      else
        {:standard, nil}
      end

    attrs = %{
      "qlink_page_id" => page.id,
      "qlink_section_id" => section_id,
      "type" => to_string(type),
      "title" => String.slice(to_string(title), 0, 200),
      "url" => url,
      "thumbnail" => thumb,
      "display_order" => order,
      "is_visible" => true,
      "embed_config" => embed_config
    }

    case Qlink.create_link(attrs) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Failed to import link #{inspect(url)}: #{inspect(changeset.errors)}")
        :ok
    end
  end
end
