defmodule QlariusWeb.Api.Admin.MarketerController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.Marketers
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    marketers = Marketers.list(params)
    json(conn, %{count: length(marketers), marketers: Enum.map(marketers, &marketer_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Marketers.fetch(id) do
      {:ok, marketer} -> json(conn, %{marketer: marketer_json(marketer)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case Marketers.create(conn.assigns.current_scope, params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(create_body(result))
      {:ok, result} -> json(conn, create_body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, marketer} <- Marketers.fetch(id),
         {:ok, result} <-
           Marketers.update(scope, marketer, params, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, marketer} <- Marketers.fetch(id),
         {:ok, result} <- Marketers.delete(scope, marketer, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp create_body(result) do
    Map.put(body(result), :matched, result.result not in ~w(created would_create))
  end

  defp body(%{result: result, record: marketer, differences: differences}) do
    %{result: result, marketer: marketer_json(marketer), differences: differences}
  end

  defp marketer_json(marketer) do
    marketer
    |> Map.take([
      :id,
      :api_ref,
      :business_name,
      :business_url,
      :contact_first_name,
      :contact_last_name,
      :contact_number,
      :contact_email,
      :sic_code,
      :created_at,
      :updated_at
    ])
    |> Map.put(:counts, Map.get(marketer, :counts))
  end
end
