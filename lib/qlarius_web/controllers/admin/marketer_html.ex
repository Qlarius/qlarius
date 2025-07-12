defmodule QlariusWeb.Admin.MarketerHTML do
  use QlariusWeb, :html

  embed_templates "marketer_html/*"

  @doc """
  Renders a marketer form.

  The form is defined in the template at
  marketer_html/marketer_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def marketer_form(assigns)
end
