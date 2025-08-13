defmodule QlariusWeb.MediaPieceHTML do
  use QlariusWeb, :html

  embed_templates "media_piece_html/*"

  # Commented out unused alias - ThreeTapBanner not directly referenced
  # alias QlariusWeb.ThreeTapBanner

  @debug true

  @doc """
  Renders a media piece form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :ad_categories, :list, required: true
  attr :conn, Plug.Conn, required: true

  def media_piece_form(assigns)
end
