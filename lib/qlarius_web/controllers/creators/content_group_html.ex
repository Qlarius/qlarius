defmodule QlariusWeb.Creators.ContentGroupHTML do
  use QlariusWeb, :html

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.TiqitClassHTML

  embed_templates "content_group_html/*"

  def content_group_image_url(%ContentGroup{} = group) do
    QlariusWeb.Uploaders.CreatorImage.url({group.image, group}, :original)
  end

  def content_group_iframe_url(conn, %ContentGroup{} = group) do
    origin =
      if conn.host == "localhost" do
        "localhost:4000"
      else
        conn.host
      end

    "#{conn.scheme}://#{origin}/widgets/arqade/group/#{group.id}"
  end

  @doc """
  Normalizes description text for compact list rows.

  Strips BOM / zero-width characters, trims ends, removes leading blank
  lines, and avoids a leading "empty line" when the HEEx source would
  otherwise inject whitespace before the interpolation (harmless with
  `whitespace-normal`, but visible with `whitespace-pre-line`).
  """
  def piece_list_description(nil), do: ""

  def piece_list_description(text) when is_binary(text) do
    text
    |> String.replace(~r/[\x{FEFF}\x{200B}\x{200C}\x{200D}]/u, "")
    |> String.trim()
    |> String.replace(~r/\A(?:\r?\n)+/u, "")
  end

  @doc """
  Renders the lesson description `<p>` without leading HEEx whitespace
  inside the tag (which `whitespace-pre-line` would otherwise show as
  a blank first line).
  """
  def piece_description_p_tag(description) when is_binary(description) do
    {:safe, escaped} = html_escape(piece_list_description(description))

    {:safe,
     [
       ~s(<p class="description-text text-sm leading-snug text-base-content/70 line-clamp-3 whitespace-pre-line">),
       escaped,
       "</p>"
     ]}
  end

  def group_card_description_p_tag(description) when is_binary(description) do
    {:safe, escaped} = html_escape(piece_list_description(description))

    {:safe,
     [
       ~s(<p class="prose prose-sm max-w-none max-h-[7.5rem] overflow-y-auto text-base-content/80 italic whitespace-pre-line">),
       escaped,
       "</p>"
     ]}
  end
end
