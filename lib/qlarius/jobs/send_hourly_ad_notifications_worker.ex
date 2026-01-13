defmodule Qlarius.Jobs.SendHourlyAdNotificationsWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  alias Qlarius.Notifications
  alias Qlarius.Sponster.Offers
  alias Qlarius.Sponster.Offer
  alias Qlarius.Repo
  alias Qlarius.DateTime, as: QlariusDateTime
  import Ecto.Query

  @impl Oban.Worker
  def perform(_job) do
    current_utc_time = DateTime.utc_now()
    Logger.info("[AdNotifications] Starting hourly ad count notifications at #{current_utc_time}")

    users = Notifications.get_users_with_notification_preferences()

    users_to_notify =
      Enum.filter(users, fn user ->
        user_local_hour = QlariusDateTime.current_hour_in_timezone(user.timezone || "America/New_York")

        pref = Notifications.get_preference(user.id, "web_push", "ad_count")
        should_notify = pref && pref.enabled && user_local_hour in (pref.preferred_hours || [])

        if should_notify do
          Logger.debug(
            "[AdNotifications] User #{user.id} matches: local_hour=#{user_local_hour}, tz=#{user.timezone}"
          )
        end

        should_notify
      end)

    Logger.info("[AdNotifications] Found #{length(users_to_notify)} users to notify")

    results =
      Enum.map(users_to_notify, fn user ->
        case send_notification_for_user(user) do
          {:ok, :sent} ->
            Logger.info("[AdNotifications] Sent notification to user #{user.id}")
            {:ok, :sent}

          {:ok, :no_ads} ->
            Logger.debug("[AdNotifications] User #{user.id} has no ads, skipping")
            {:ok, :skipped}

          {:ok, :no_subscriptions} ->
            Logger.debug("[AdNotifications] User #{user.id} has no active subscriptions")
            {:ok, :skipped}

          {:error, reason} ->
            Logger.error("[AdNotifications] Failed to send to user #{user.id}: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    successful = Enum.count(results, fn result -> match?({:ok, :sent}, result) end)
    skipped = Enum.count(results, fn result -> match?({:ok, _}, result) end) - successful
    failed = Enum.count(results, fn result -> match?({:error, _}, result) end)

    Logger.info(
      "[AdNotifications] Completed: #{successful} sent, #{skipped} skipped, #{failed} failed"
    )

    {:ok, %{successful: successful, skipped: skipped, failed: failed}}
  end

  defp send_notification_for_user(user) do
    me_file = Repo.preload(user, :me_file).me_file

    active_offers = get_active_offers(me_file.id)
    ad_count = length(active_offers)

    if ad_count == 0 do
      {:ok, :no_ads}
    else
      total_value = Offers.total_active_offer_amount(me_file) || Decimal.new(0)
      total_value_float = Decimal.to_float(total_value)

      Notifications.send_ad_count_notification(user, ad_count, total_value_float)
    end
  end

  defp get_active_offers(me_file_id) do
    from(o in Offer,
      where: o.me_file_id == ^me_file_id and o.is_current == true,
      order_by: [desc: o.offer_amt]
    )
    |> Repo.all()
  end
end
