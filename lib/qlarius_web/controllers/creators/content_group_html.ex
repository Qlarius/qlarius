defmodule QlariusWeb.Creators.ContentGroupHTML do
  use QlariusWeb, :html

  alias Qlarius.Tiqit.Arcade.ContentGroup

  embed_templates "content_group_html/*"

  @doc """
  Renders a content_group form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def content_group_form(assigns)

  def content_group_image_url(%ContentGroup{} = group) do
    QlariusWeb.Uploaders.ContentGroupImage.url({group.image, group}, :original)
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
