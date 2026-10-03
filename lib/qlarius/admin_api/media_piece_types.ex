defmodule Qlarius.AdminApi.MediaPieceTypes do
  @moduledoc """
  Read model of media piece types for the admin campaign API.

  Required fields match `MediaPiece.changeset/2`. Video types are listed so an
  agent can see them, but the API does not accept video uploads yet.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPieceType}

  def list do
    Repo.all(from(t in MediaPieceType, order_by: [asc: t.id]))
  end

  def required_fields(1), do: ~w(banner_image display_url jump_url)
  def required_fields(2), do: ~w(video_file duration)
  def required_fields(_id), do: []

  def writable?(1), do: true
  def writable?(_id), do: false

  def field_limits(1) do
    %{"title" => MediaPiece.three_tap_title_max(), "body_copy" => MediaPiece.three_tap_body_max()}
  end

  def field_limits(_id), do: %{}
end
