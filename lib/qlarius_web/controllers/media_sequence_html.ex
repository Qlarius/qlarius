defmodule QlariusWeb.MediaSequenceHTML do
  use QlariusWeb, :html

  embed_templates "media_sequence_html/*"

  @doc """
  Renders a media sequence form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :media_pieces, :list, required: true

  def media_run_form(assigns)
end
