defmodule QlariusWeb.Api.Admin.AuditLogController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.TraitAudit
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, %{"trait_id" => raw}) when raw not in [nil, ""] do
    case Integer.parse(to_string(raw)) do
      {trait_id, ""} ->
        entries = trait_id |> TraitAudit.list() |> Enum.map(&TraitAudit.to_json/1)
        json(conn, %{entries: entries})

      _ ->
        Responder.error(conn, :trait_id_required)
    end
  end

  def index(conn, _params), do: Responder.error(conn, :trait_id_required)
end
