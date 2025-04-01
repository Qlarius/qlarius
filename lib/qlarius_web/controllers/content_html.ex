defmodule QlariusWeb.ContentHTML do
  use QlariusWeb, :html

  embed_templates "content_html/*"

  @doc """
  Renders a content form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def content_form(assigns) do
    ~H"""
    <.simple_form :let={f} for={@changeset} action={@action}>
      <.error :if={@changeset.action}>
        Oops, something went wrong! Please check the errors below.
      </.error>
      <.input field={f[:title]} type="text" label="Title" />
      <.input field={f[:date_published]} type="date" label="Published Date" />
      <.input field={f[:description]} type="textarea" label="Description" />
      <:actions>
        <.button>Save Content</.button>
      </:actions>
    </.simple_form>
    """
  end
end
