defmodule QlariusWeb.MediaPieceHTML do
  use QlariusWeb, :html

  embed_templates "media_piece_html/*"

  @doc """
  Renders a media piece form.
  """
  attr :action, :string, required: true
  attr :ad_categories, :list, required: true
  attr :changeset, Ecto.Changeset, required: true
  attr :marketers, :list, required: true

  def media_piece_form(assigns)
end
