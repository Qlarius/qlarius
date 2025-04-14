defmodule QlariusWeb.Creators.ContentGroupHTML do
  use QlariusWeb, :html

  embed_templates "content_group_html/*"

  @doc """
  Renders a content_group form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def content_group_form(assigns)
end
