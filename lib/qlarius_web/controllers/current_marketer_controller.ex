defmodule QlariusWeb.CurrentMarketerController do
  use QlariusWeb, :controller

  alias QlariusWeb.Live.Marketers.CurrentMarketer

  @default_return_to "/admin/marketers"
  @allowed_return_prefixes ["/admin/marketers", "/marketer/"]

  def select(conn, %{"marketer_id" => marketer_id} = params) do
    return_to = safe_return_to(params["return_to"])

    case CurrentMarketer.resolve(conn.assigns.current_scope, marketer_id) do
      nil ->
        conn
        |> put_flash(:error, "Marketer not found.")
        |> redirect(to: return_to)

      marketer ->
        conn
        |> put_session(:current_marketer_id, marketer.id)
        |> put_flash(:info, "Current marketer set to #{marketer.business_name}.")
        |> redirect(to: return_to)
    end
  end

  defp safe_return_to(path) when is_binary(path) do
    if Enum.any?(@allowed_return_prefixes, &String.starts_with?(path, &1)),
      do: path,
      else: @default_return_to
  end

  defp safe_return_to(_path), do: @default_return_to
end
