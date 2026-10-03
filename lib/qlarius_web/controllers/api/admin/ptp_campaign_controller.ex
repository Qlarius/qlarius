defmodule QlariusWeb.Api.Admin.PtpCampaignController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.PtpBuilds
  alias QlariusWeb.Api.Admin.Responder

  def build(conn, params) do
    case PtpBuilds.build(conn.assigns.current_scope, params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(money(result))
      {:ok, result} -> json(conn, money(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp money(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp money(%_{} = value), do: value
  defp money(value) when is_map(value), do: Map.new(value, fn {k, v} -> {k, money(v)} end)
  defp money(value) when is_list(value), do: Enum.map(value, &money/1)
  defp money(value), do: value
end
