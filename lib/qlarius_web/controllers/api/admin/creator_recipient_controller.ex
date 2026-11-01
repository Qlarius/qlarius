defmodule QlariusWeb.Api.Admin.CreatorRecipientController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.{CreatorRecipients, Creators}
  alias QlariusWeb.Api.Admin.RecipientController
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, %{"creator_id" => creator_id}) do
    with {:ok, creator} <- Creators.fetch(creator_id) do
      recipients = CreatorRecipients.list(creator)

      json(conn, %{
        count: length(recipients),
        recipients: Enum.map(recipients, &RecipientController.recipient_json/1)
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def show(conn, %{"creator_id" => creator_id, "id" => id}) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, recipient} <- CreatorRecipients.fetch(creator, id) do
      json(conn, %{recipient: RecipientController.recipient_json(recipient)})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, %{"creator_id" => creator_id} = params) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, result} <-
           CreatorRecipients.create(conn.assigns.current_scope, creator, params,
             dry_run: Responder.dry_run?(params)
           ) do
      conn = if result.result == "created", do: put_status(conn, 201), else: conn
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"creator_id" => creator_id, "id" => id} = params) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, recipient} <- CreatorRecipients.fetch(creator, id),
         {:ok, result} <-
           CreatorRecipients.update(conn.assigns.current_scope, creator, recipient, params,
             dry_run: Responder.dry_run?(params)
           ) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def archive(conn, %{"creator_id" => creator_id, "id" => id} = params) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, recipient} <- CreatorRecipients.fetch(creator, id),
         {:ok, result} <-
           CreatorRecipients.archive(creator, recipient, dry_run: Responder.dry_run?(params)) do
      json(conn, body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"creator_id" => creator_id, "id" => id} = params) do
    with {:ok, creator} <- Creators.fetch(creator_id),
         {:ok, recipient} <- CreatorRecipients.fetch(creator, id),
         {:ok, result} <-
           CreatorRecipients.delete(creator, recipient, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp body(%{result: result, record: recipient, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      recipient: RecipientController.recipient_json(recipient),
      differences: differences
    }
  end
end
