defmodule QlariusWeb.Creators.CatalogHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents

  embed_templates "catalog_html/*"

  @doc """
  Renders a catalog form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def catalog_form(assigns)
end
