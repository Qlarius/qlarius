defmodule QlariusWeb.PushController do
  use QlariusWeb, :controller

  require Logger
  alias Qlarius.Notifications

  def vapid_public_key(conn, _params) do
    public_key = Application.fetch_env!(:qlarius, :vapid_public_key)
    json(conn, %{publicKey: public_key})
  end

  def subscribe(conn, %{"subscription" => sub_data} = params) do
    user_id = conn.assigns.current_scope.user.id

    Logger.debug("Received subscription data from browser: #{inspect(sub_data)}")
    Logger.debug("Subscription data keys: #{inspect(Map.keys(sub_data))}")

    case Notifications.subscribe_to_push(
           user_id,
           sub_data,
           %{
             type: params["device_type"],
             user_agent: params["user_agent"]
           }
         ) do
      {:ok, _subscription} ->
        Logger.info("User #{user_id} subscribed to push notifications")
        json(conn, %{success: true})

      {:error, changeset} ->
        Logger.error("Failed to subscribe user #{user_id}: #{inspect(changeset)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to subscribe"})
    end
  end

  def unsubscribe(conn, %{"subscription_id" => sub_id}) do
    case Notifications.unsubscribe_from_push(sub_id) do
      {:ok, _subscription} ->
        Logger.info("Unsubscribed from push notifications: #{sub_id}")
        json(conn, %{success: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Subscription not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def track_click(conn, %{"url" => _url}) do
    json(conn, %{success: true})
  end
end
