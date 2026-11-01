defmodule QlariusWeb.Api.Admin.TiqitClassController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.TiqitClasses
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    case TiqitClasses.list(params) do
      {:ok, classes} ->
        json(conn, %{count: length(classes), tiqit_classes: Enum.map(classes, &class_json/1)})

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  defp class_json(class) do
    %{
      id: class.id,
      catalog_id: class.catalog_id,
      content_group_id: class.content_group_id,
      content_piece_id: class.content_piece_id,
      duration_hours: class.duration_hours,
      price: class.price,
      active: class.active
    }
  end
end