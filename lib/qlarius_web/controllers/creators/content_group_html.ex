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

    "#{conn.scheme}://#{origin}/widgets/arcade/group/#{group.id}"
  end
end
