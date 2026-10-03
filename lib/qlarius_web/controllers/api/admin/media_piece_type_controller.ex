defmodule QlariusWeb.Api.Admin.MediaPieceTypeController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.MediaPieceTypes

  def index(conn, _params) do
    types = Enum.map(MediaPieceTypes.list(), &type_json/1)
    json(conn, %{count: length(types), media_piece_types: types})
  end

  defp type_json(type) do
    %{
      id: type.id,
      name: type.name,
      description: type.desc,
      ad_phase_count_to_complete: type.ad_phase_count_to_complete,
      base_fee: decimal(type.base_fee),
      markup_multiplier: decimal(type.markup_multiplier),
      required_fields: MediaPieceTypes.required_fields(type.id),
      field_limits: MediaPieceTypes.field_limits(type.id),
      writable: MediaPieceTypes.writable?(type.id)
    }
  end

  defp decimal(nil), do: nil
  defp decimal(%Decimal{} = value), do: Decimal.to_string(value, :normal)
end
