defmodule QlariusWeb.Creators.CreatorHTML do
  use QlariusWeb, :html

  import QlariusWeb.CoreComponents
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  embed_templates "creator_html/*"

  @doc """
  Renders a creator form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def creator_form(assigns)
end
