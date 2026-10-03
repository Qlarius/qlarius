defmodule QlariusWeb.Api.Admin.PtpCoverageController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.PtpCoverage
  alias QlariusWeb.Api.Admin.Responder

  def show(conn, params) do
    case PtpCoverage.report(params["month"]) do
      {:ok, report} -> json(conn, report)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end
end
