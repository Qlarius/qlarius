defmodule QlariusWeb.Api.Admin.RecipientController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.Recipients
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    recipients = Recipients.list(params)
    json(conn, %{count: length(recipients), recipients: Enum.map(recipients, &recipient_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Recipients.fetch(id) do
      {:ok, recipient} -> json(conn, %{recipient: recipient_json(recipient)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case Recipients.create(conn.assigns.current_scope, params,
           dry_run: Responder.dry_run?(params)
         ) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(body(result))
      {:ok, result} -> json(conn, body(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, recipient} <- Recipients.fetch(id),
         {:ok, result} <-
           Recipients.update(conn.assigns.current_scope, recipient, params,
             dry_run: Responder.dry_run?(params)
           ) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: recipient, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      recipient: recipient_json(recipient),
      differences: differences
    }
  end

  def recipient_json(recipient) do
    %{
      id: recipient.id,
      api_ref: recipient.api_ref,
      creator_id: recipient.creator_id,
      name: recipient.name,
      description: recipient.description,
      message: recipient.message,
      site_url: recipient.site_url,
      contact_email: recipient.contact_email,
      graphic_url: recipient.graphic_url,
      split_code: recipient.split_code,
      referral_code: recipient.referral_code,
      recipient_type_id: recipient.recipient_type_id,
      is_primary: recipient.is_primary,
      archived_at: recipient.archived_at,
      approval_date: recipient.approval_date,
      user_id: recipient.user_id
    }
  end
end
