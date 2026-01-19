defmodule Qlarius.Notifications do
  @moduledoc """
  Internal notification system with full data sovereignty.
  Manages preferences, delivery, and tracking across all channels.
  """

  import Ecto.Query
  require Logger

  alias Qlarius.Repo
  alias Qlarius.Notifications.{PushSubscription, Preference, Log}
  alias Qlarius.System

  @default_preferred_hours [9, 18]
  @default_cta "Tap to access and sell your attention now."

  def subscribe_to_push(user_id, subscription_data, device_info \\ %{}) do
    %PushSubscription{}
    |> PushSubscription.changeset(%{
      user_id: user_id,
      subscription_data: subscription_data,
      device_type: device_info[:type],
      user_agent: device_info[:user_agent],
      last_used_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def unsubscribe_from_push(subscription_id) do
    case Repo.get(PushSubscription, subscription_id) do
      nil ->
        {:error, :not_found}

      sub ->
        sub
        |> PushSubscription.changeset(%{active: false})
        |> Repo.update()
    end
  end

  def unsubscribe_by_endpoint(user_id, endpoint) do
    require Logger
    Logger.info("Attempting to unsubscribe user_id=#{user_id}, endpoint=#{String.slice(endpoint, 0..50)}...")
    
    # Query by JSON fragment to find the subscription
    query =
      from(s in PushSubscription,
        where:
          s.user_id == ^user_id and
            s.active == true and
            fragment("?->>'endpoint' = ?", s.subscription_data, ^endpoint)
      )

    case Repo.one(query) do
      nil ->
        Logger.warning("No active subscription found for endpoint")
        {:error, :not_found}

      sub ->
        Logger.info("Found subscription id=#{sub.id}, marking as inactive")
        result = sub
        |> PushSubscription.changeset(%{active: false})
        |> Repo.update()
        
        Logger.info("Unsubscribe result: #{inspect(result)}")
        result
    end
  end

  def get_active_subscriptions(user_id) do
    from(s in PushSubscription,
      where: s.user_id == ^user_id and s.active == true
    )
    |> Repo.all()
  end

  def get_preferences(user_id) do
    from(p in Preference, where: p.user_id == ^user_id)
    |> Repo.all()
  end

  def get_preference(user_id, channel, category) do
    Repo.get_by(Preference, user_id: user_id, channel: channel, category: category)
  end

  def update_preference(user_id, channel, category, attrs) do
    case get_preference(user_id, channel, category) do
      nil ->
        %Preference{}
        |> Preference.changeset(
          Map.merge(attrs, %{
            user_id: user_id,
            channel: channel,
            category: category
          })
        )
        |> Repo.insert()

      pref ->
        pref
        |> Preference.changeset(attrs)
        |> Repo.update()
    end
  end

  def ensure_default_preferences(user_id) do
    case get_preference(user_id, "web_push", "ad_count") do
      nil ->
        update_preference(user_id, "web_push", "ad_count", %{
          enabled: true,
          preferred_hours: @default_preferred_hours,
          quiet_hours_start: ~T[22:00:00],
          quiet_hours_end: ~T[07:00:00]
        })

      _existing ->
        {:ok, :already_exists}
    end
  end

  def get_users_with_notification_preferences do
    from(p in Preference,
      where:
        p.channel == "web_push" and
          p.category == "ad_count" and
          p.enabled == true,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(& &1.user)
  end

  def get_users_for_hourly_notification(hour) do
    from(p in Preference,
      where:
        p.channel == "web_push" and
          p.category == "ad_count" and
          p.enabled == true and
          ^hour in p.preferred_hours,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(& &1.user)
  end

  def should_send_now?(user_id, hour) do
    pref = get_preference(user_id, "web_push", "ad_count")

    cond do
      is_nil(pref) -> false
      !pref.enabled -> false
      in_quiet_hours?(hour, pref) -> false
      hour not in (pref.preferred_hours || []) -> false
      true -> true
    end
  end

  defp in_quiet_hours?(hour, pref) do
    case {pref.quiet_hours_start, pref.quiet_hours_end} do
      {nil, nil} ->
        false

      {start_time, end_time} ->
        current_time = Time.new!(hour, 0, 0)

        if Time.compare(start_time, end_time) == :gt do
          Time.compare(current_time, start_time) != :lt or
            Time.compare(current_time, end_time) != :gt
        else
          Time.compare(current_time, start_time) != :lt and
            Time.compare(current_time, end_time) != :gt
        end
    end
  end

  def send_ad_count_notification(user, ad_count, total_value) do
    subscriptions = get_active_subscriptions(user.id)

    Logger.info(
      "Sending ad count notification to user #{user.id}, found #{length(subscriptions)} subscriptions"
    )

    if Enum.empty?(subscriptions) do
      {:ok, :no_subscriptions}
    else
      notification = build_ad_count_notification(ad_count, total_value)
      Logger.info("Built notification: #{inspect(notification)}")

      results =
        Enum.map(subscriptions, fn sub ->
          result = send_web_push(sub, notification)
          Logger.info("Web push result: #{inspect(result)}")
          result
        end)

      log_notification(user.id, :ad_count, "web_push", notification)

      if Enum.any?(results, &match?({:ok, _}, &1)) do
        {:ok, :sent}
      else
        Logger.error("All web push sends failed: #{inspect(results)}")
        {:error, :all_failed}
      end
    end
  end

  defp build_ad_count_notification(ad_count, total_value) do
    formatted_value = :erlang.float_to_binary(total_value, decimals: 2)
    cta = get_random_cta()

    %{
      title: "Sponster",
      body: "You have #{ad_count} sponsor ads totaling $#{formatted_value}. #{cta}",
      icon: "/images/qadabra_app_icon_192.png",
      badge: "/images/qadabra_app_icon_192.png",
      data: %{
        url: "/ads",
        unread_count: ad_count
      }
    }
  end

  defp get_random_cta() do
    case System.get_global_variable("PUSH_NOTIFICATION_SPONSTER_ADS_CTAS") do
      nil ->
        @default_cta

      ctas_string when is_binary(ctas_string) ->
        ctas_string
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> @default_cta
          ctas -> Enum.random(ctas)
        end

      _ ->
        @default_cta
    end
  end

  defp send_web_push(subscription, notification) do
    Logger.info("Sending web push notification")
    Logger.debug("Full subscription data structure: #{inspect(subscription.subscription_data)}")

    subscription_with_atom_keys = %{
      endpoint: subscription.subscription_data["endpoint"],
      keys: %{
        auth: subscription.subscription_data["keys"]["auth"],
        p256dh: subscription.subscription_data["keys"]["p256dh"]
      }
    }

    Logger.debug("Subscription with atom keys: #{inspect(subscription_with_atom_keys)}")

    payload = Jason.encode!(notification)
    Logger.debug("Push payload: #{payload}")

    case WebPushEncryption.send_web_push(payload, subscription_with_atom_keys) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        Logger.info("Web push delivered successfully: #{status}")
        update_subscription_last_used(subscription)
        {:ok, :delivered}

      {:ok, %{status_code: 410} = resp} ->
        Logger.warning("Subscription expired (410): #{inspect(resp)}")
        mark_subscription_inactive(subscription)
        {:error, :subscription_expired}

      {:ok, %{status_code: status} = resp} ->
        Logger.error("Web push failed with status #{status}: #{inspect(resp)}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to send web push: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp update_subscription_last_used(subscription) do
    subscription
    |> PushSubscription.changeset(%{last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp mark_subscription_inactive(subscription) do
    subscription
    |> PushSubscription.changeset(%{active: false})
    |> Repo.update()
  end

  defp log_notification(user_id, type, channel, notification) do
    %Log{}
    |> Log.changeset(%{
      user_id: user_id,
      notification_type: to_string(type),
      channel: channel,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      sent_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def mark_delivered(log_id) do
    case Repo.get(Log, log_id) do
      nil ->
        {:error, :not_found}

      log ->
        log
        |> Ecto.Changeset.change(%{delivered_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def mark_clicked(log_id) do
    case Repo.get(Log, log_id) do
      nil ->
        {:error, :not_found}

      log ->
        log
        |> Ecto.Changeset.change(%{clicked_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def get_notification_stats(user_id, days_back \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days_back * 24 * 60 * 60, :second)

    from(l in Log,
      where: l.user_id == ^user_id and l.sent_at > ^since,
      select: %{
        total_sent: count(l.id),
        delivered: fragment("COUNT(?) FILTER (WHERE ? IS NOT NULL)", l.id, l.delivered_at),
        clicked: fragment("COUNT(?) FILTER (WHERE ? IS NOT NULL)", l.id, l.clicked_at),
        failed: fragment("COUNT(?) FILTER (WHERE ? IS NOT NULL)", l.id, l.failed_at)
      }
    )
    |> Repo.one()
  end
end
