defmodule QlariusWeb.MediaPieceHTML do
  use QlariusWeb, :html

  embed_templates "media_piece_html/*"

  @doc """
  Renders a media piece form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :ad_categories, :list, required: true

  def media_piece_form(assigns)
end
