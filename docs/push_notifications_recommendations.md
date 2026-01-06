# Push Notifications Implementation Guide

**Last Updated:** January 6, 2025  
**For:** Qlarius Multi-Channel Notification System  
**Priority:** Data Sovereignty + Privacy First

---

## Executive Summary

This document outlines the recommended approach for implementing push notifications in Qlarius with complete data sovereignty. All user data, preferences, and notification rules remain in our control.

### Channels to Support:
1. **Web Push** (Browser/PWA) - Primary, implement first
2. **SMS** (Twilio) - Already implemented, integrate into unified system
3. **Mobile Push** (iOS/Android) - Future, when native apps are built

---

## Phase 1: Web Push (Implement First)

### Technology Stack

**Library:** `web_push_encryption` (Elixir)  
**Protocol:** VAPID (Voluntary Application Server Identification)  
**Cost:** $0 (self-hosted)  
**Implementation Time:** 1-2 days

### Why This Approach?

✅ **100% Data Sovereignty** - All subscriptions stored in our DB  
✅ **No Third-Party Services** - Direct browser communication  
✅ **Privacy Compliant** - GDPR/CCPA ready  
✅ **Works with PWA** - Perfect for our architecture  
✅ **Free Forever** - No per-message costs  
✅ **Full Control** - All rules in Elixir code  

### Architecture

```
User Browser
    ↓ (grants permission)
Store subscription in our DB
    ↓
Oban Job triggers notification
    ↓
Phoenix sends via web_push_encryption
    ↓
Browser receives & displays
```

### Database Schema

```sql
-- User push subscriptions
CREATE TABLE push_subscriptions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_data JSONB NOT NULL,  -- Contains endpoint, keys, etc.
  device_type VARCHAR(50),            -- 'chrome', 'firefox', 'safari', etc.
  user_agent TEXT,
  active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX push_subscriptions_user_id_index ON push_subscriptions(user_id);
CREATE INDEX push_subscriptions_active_index ON push_subscriptions(active);

-- User notification preferences
CREATE TABLE notification_preferences (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel VARCHAR(50) NOT NULL,       -- 'web_push', 'mobile_push', 'sms'
  category VARCHAR(50) NOT NULL,      -- 'new_ads', 'wallet', 'reminders'
  enabled BOOLEAN DEFAULT true,
  quiet_hours_start TIME,             -- e.g., '22:00'
  quiet_hours_end TIME,               -- e.g., '08:00'
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(user_id, channel, category)
);

-- Notification audit log (our analytics)
CREATE TABLE notification_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type VARCHAR(50) NOT NULL,
  channel VARCHAR(50) NOT NULL,
  title TEXT,
  body TEXT,
  data JSONB,                         -- Custom payload
  sent_at TIMESTAMP NOT NULL DEFAULT NOW(),
  delivered_at TIMESTAMP,
  clicked_at TIMESTAMP,
  failed_at TIMESTAMP,
  failure_reason TEXT
);

CREATE INDEX notification_logs_user_id_index ON notification_logs(user_id);
CREATE INDEX notification_logs_sent_at_index ON notification_logs(sent_at);
```

### Elixir Schemas

```elixir
# lib/qlarius/notifications/push_subscription.ex
defmodule Qlarius.Notifications.PushSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "push_subscriptions" do
    field :subscription_data, :map
    field :device_type, :string
    field :user_agent, :string
    field :active, :boolean, default: true
    field :last_used_at, :utc_datetime

    belongs_to :user, Qlarius.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:user_id, :subscription_data, :device_type, :user_agent, :active])
    |> validate_required([:user_id, :subscription_data])
    |> foreign_key_constraint(:user_id)
  end
end

# lib/qlarius/notifications/preference.ex
defmodule Qlarius.Notifications.Preference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_preferences" do
    field :channel, :string
    field :category, :string
    field :enabled, :boolean, default: true
    field :quiet_hours_start, :time
    field :quiet_hours_end, :time

    belongs_to :user, Qlarius.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :channel, :category, :enabled, :quiet_hours_start, :quiet_hours_end])
    |> validate_required([:user_id, :channel, :category])
    |> validate_inclusion(:channel, ["web_push", "mobile_push", "sms"])
    |> validate_inclusion(:category, ["new_ads", "wallet", "reminders", "engagement"])
    |> unique_constraint([:user_id, :channel, :category])
  end
end

# lib/qlarius/notifications/log.ex
defmodule Qlarius.Notifications.Log do
  use Ecto.Schema

  schema "notification_logs" do
    field :notification_type, :string
    field :channel, :string
    field :title, :string
    field :body, :string
    field :data, :map
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :failed_at, :utc_datetime
    field :failure_reason, :string

    belongs_to :user, Qlarius.Accounts.User
  end
end
```

### Notification Context

```elixir
# lib/qlarius/notifications.ex
defmodule Qlarius.Notifications do
  @moduledoc """
  Internal notification system with full data sovereignty.
  Manages preferences, delivery, and tracking across all channels.
  """

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Notifications.{PushSubscription, Preference, Log}

  # Subscription Management
  
  def subscribe_to_push(user_id, subscription_data, device_info \\ %{}) do
    %PushSubscription{}
    |> PushSubscription.changeset(%{
      user_id: user_id,
      subscription_data: subscription_data,
      device_type: device_info[:type],
      user_agent: device_info[:user_agent]
    })
    |> Repo.insert()
  end

  def unsubscribe_from_push(subscription_id) do
    case Repo.get(PushSubscription, subscription_id) do
      nil -> {:error, :not_found}
      sub -> 
        sub
        |> PushSubscription.changeset(%{active: false})
        |> Repo.update()
    end
  end

  def get_active_subscriptions(user_id) do
    from(s in PushSubscription,
      where: s.user_id == ^user_id and s.active == true
    )
    |> Repo.all()
  end

  # Preferences Management

  def get_preferences(user_id) do
    from(p in Preference, where: p.user_id == ^user_id)
    |> Repo.all()
  end

  def update_preference(user_id, channel, category, enabled) do
    case Repo.get_by(Preference, user_id: user_id, channel: channel, category: category) do
      nil ->
        %Preference{}
        |> Preference.changeset(%{
          user_id: user_id,
          channel: channel,
          category: category,
          enabled: enabled
        })
        |> Repo.insert()

      pref ->
        pref
        |> Preference.changeset(%{enabled: enabled})
        |> Repo.update()
    end
  end

  # Notification Rules (Internal Logic)

  def should_send?(user_id, notification_type) do
    user = Qlarius.Accounts.get_user!(user_id)
    prefs = get_preferences(user_id)

    cond do
      # Don't send new_ads if user has balance
      notification_type == :new_ads && Decimal.gt?(user.me_file.wallet_balance, 0) ->
        false

      # Check if category is disabled
      category_disabled?(prefs, notification_type) ->
        false

      # Check quiet hours
      in_quiet_hours?(prefs) ->
        false

      # Default: allow
      true ->
        true
    end
  end

  defp category_disabled?(prefs, notification_type) do
    category = notification_type_to_category(notification_type)
    
    Enum.any?(prefs, fn pref ->
      pref.category == category && !pref.enabled
    end)
  end

  defp in_quiet_hours?(prefs) do
    # Get web_push quiet hours
    case Enum.find(prefs, &(&1.channel == "web_push" && &1.quiet_hours_start)) do
      nil -> false
      pref ->
        now = Time.utc_now()
        Time.compare(now, pref.quiet_hours_start) == :gt &&
        Time.compare(now, pref.quiet_hours_end) == :lt
    end
  end

  defp notification_type_to_category(:new_ads), do: "new_ads"
  defp notification_type_to_category(:wallet_activity), do: "wallet"
  defp notification_type_to_category(:reminder), do: "reminders"
  defp notification_type_to_category(:engagement), do: "engagement"

  # Notification Delivery

  def send_notification(user_id, type, data) do
    if should_send?(user_id, type) do
      subscriptions = get_active_subscriptions(user_id)
      
      notification = build_notification(type, data)
      
      Enum.each(subscriptions, fn sub ->
        send_web_push(sub, notification)
      end)
      
      log_notification(user_id, type, "web_push", notification)
      
      {:ok, :sent}
    else
      {:ok, :skipped}
    end
  end

  defp build_notification(:new_ads, data) do
    %{
      title: "New offers available! 🎯",
      body: "You have #{data.count} new ads worth $#{data.value}",
      icon: "/images/qadabra_icon.png",
      data: %{url: "/ads"}
    }
  end

  defp build_notification(:wallet_activity, data) do
    %{
      title: "💰 You earned $#{data.amount}!",
      body: "Payment processed",
      icon: "/images/qadabra_icon.png",
      data: %{url: "/wallet"}
    }
  end

  defp send_web_push(subscription, notification) do
    case WebPushEncryption.send_web_push(
      notification,
      subscription.subscription_data,
      vapid_public_key: Application.fetch_env!(:qlarius, :vapid_public_key),
      vapid_private_key: Application.fetch_env!(:qlarius, :vapid_private_key),
      vapid_subject: "mailto:support@qlarius.com"
    ) do
      {:ok, _response} ->
        update_subscription_last_used(subscription)
        {:ok, :delivered}

      {:error, reason} ->
        mark_subscription_failed(subscription, reason)
        {:error, reason}
    end
  end

  defp log_notification(user_id, type, channel, notification) do
    %Log{
      user_id: user_id,
      notification_type: to_string(type),
      channel: channel,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      sent_at: DateTime.utc_now()
    }
    |> Repo.insert()
  end

  # Analytics

  def mark_delivered(log_id) do
    case Repo.get(Log, log_id) do
      nil -> {:error, :not_found}
      log ->
        log
        |> Ecto.Changeset.change(%{delivered_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def mark_clicked(log_id) do
    case Repo.get(Log, log_id) do
      nil -> {:error, :not_found}
      log ->
        log
        |> Ecto.Changeset.change(%{clicked_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def get_notification_stats(user_id, days_back \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    from(l in Log,
      where: l.user_id == ^user_id and l.sent_at > ^since,
      select: %{
        total_sent: count(l.id),
        delivered: count(l.delivered_at),
        clicked: count(l.clicked_at),
        failed: count(l.failed_at)
      }
    )
    |> Repo.one()
  end
end
```

### Integration with Oban Jobs

```elixir
# Example: Trigger notification after ads are reconciled
# lib/qlarius/jobs/reconcile_offers_for_mefile_worker.ex

def perform(%Oban.Job{args: %{"me_file_id" => me_file_id}}) do
  # ... existing reconciliation logic ...
  
  # After reconciliation, check if we should notify
  offers_count = Qlarius.Sponster.count_active_offers(me_file_id)
  total_value = Qlarius.Sponster.calculate_offers_value(me_file_id)
  
  if offers_count > 0 do
    Qlarius.Notifications.send_notification(
      me_file.user_id,
      :new_ads,
      %{count: offers_count, value: total_value}
    )
  end
  
  {:ok, :completed}
end
```

### Frontend Implementation (JavaScript)

```javascript
// assets/js/notifications.js

export const Notifications = {
  mounted() {
    this.initPushNotifications();
  },

  async initPushNotifications() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.log('Push notifications not supported');
      return;
    }

    try {
      const permission = await Notification.requestPermission();
      
      if (permission === 'granted') {
        await this.subscribeToPush();
      }
    } catch (error) {
      console.error('Failed to subscribe to push:', error);
    }
  },

  async subscribeToPush() {
    const registration = await navigator.serviceWorker.ready;
    
    // Get VAPID public key from server
    const response = await fetch('/api/push/vapid-public-key');
    const { publicKey } = await response.json();
    
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(publicKey)
    });

    // Send subscription to server
    await fetch('/api/push/subscribe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({
        subscription: subscription.toJSON(),
        device_type: this.detectBrowser(),
        user_agent: navigator.userAgent
      })
    });
  },

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  },

  detectBrowser() {
    const userAgent = navigator.userAgent;
    if (userAgent.includes('Firefox')) return 'firefox';
    if (userAgent.includes('Chrome')) return 'chrome';
    if (userAgent.includes('Safari')) return 'safari';
    if (userAgent.includes('Edge')) return 'edge';
    return 'other';
  }
};
```

### Service Worker (PWA)

```javascript
// priv/static/sw.js

self.addEventListener('push', (event) => {
  const data = event.data.json();
  
  const options = {
    body: data.body,
    icon: data.icon || '/images/qadabra_icon.png',
    badge: '/images/badge.png',
    data: data.data,
    actions: [
      { action: 'open', title: 'View' },
      { action: 'close', title: 'Dismiss' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'open' || !event.action) {
    const url = event.notification.data?.url || '/';
    
    event.waitUntil(
      clients.openWindow(url).then(client => {
        // Track click
        fetch('/api/push/track-click', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url })
        });
      })
    );
  }
});
```

### API Endpoints

```elixir
# lib/qlarius_web/controllers/push_controller.ex
defmodule QlariusWeb.PushController do
  use QlariusWeb, :controller

  def vapid_public_key(conn, _params) do
    public_key = Application.fetch_env!(:qlarius, :vapid_public_key)
    json(conn, %{publicKey: public_key})
  end

  def subscribe(conn, %{"subscription" => sub_data} = params) do
    user_id = conn.assigns.current_scope.user.id

    case Qlarius.Notifications.subscribe_to_push(
      user_id,
      sub_data,
      %{
        type: params["device_type"],
        user_agent: params["user_agent"]
      }
    ) do
      {:ok, _subscription} ->
        json(conn, %{success: true})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to subscribe"})
    end
  end

  def track_click(conn, %{"url" => url}) do
    # Track notification click for analytics
    # Implementation depends on how you identify the notification
    json(conn, %{success: true})
  end
end

# Router
scope "/api", QlariusWeb do
  pipe_through [:api, :require_authenticated_user]

  get "/push/vapid-public-key", PushController, :vapid_public_key
  post "/push/subscribe", PushController, :subscribe
  post "/push/track-click", PushController, :track_click
end
```

### Configuration

```elixir
# config/runtime.exs

# Generate VAPID keys once:
# iex> :crypto.generate_key(:ecdh, :prime256v1)

config :qlarius,
  vapid_public_key: System.get_env("VAPID_PUBLIC_KEY"),
  vapid_private_key: System.get_env("VAPID_PRIVATE_KEY"),
  vapid_subject: "mailto:support@qlarius.com"

# mix.exs dependencies
{:web_push_encryption, "~> 0.3"}
```

---

## Phase 2: SMS Integration (Already Have)

### Current Setup
- Twilio already integrated
- Phone numbers stored encrypted
- Used for verification codes

### Integration into Unified System

Add SMS as a notification channel:

```elixir
# lib/qlarius/notifications.ex (add to existing context)

def send_sms_notification(user_id, type, data) do
  user = Qlarius.Accounts.get_user!(user_id)
  
  if should_send?(user_id, type) && has_sms_enabled?(user_id) do
    phone = Qlarius.Encrypted.decrypt(user.mobile_number_encrypted)
    message = build_sms_message(type, data)
    
    case Qlarius.Services.Twilio.send_sms(phone, message) do
      {:ok, _} -> 
        log_notification(user_id, type, "sms", %{body: message})
        {:ok, :sent}
      
      {:error, reason} ->
        {:error, reason}
    end
  else
    {:ok, :skipped}
  end
end

defp build_sms_message(:wallet_activity, data) do
  "You earned $#{data.amount}! View your wallet: https://qlarius.com/wallet"
end

defp build_sms_message(:urgent_reminder, data) do
  "#{data.message} - Reply STOP to unsubscribe"
end
```

### When to Use SMS

**Use SMS for:**
- ✅ High-priority alerts only
- ✅ When push notifications aren't enabled
- ✅ Critical account actions
- ✅ Fallback for failed push

**Avoid SMS for:**
- ❌ Routine notifications (expensive)
- ❌ Marketing messages (legal issues)
- ❌ Frequent updates

---

## Phase 3: Mobile Push (Future)

### Option A: Self-Hosted ntfy

**When:** After building native iOS/Android apps

**Setup:**
```bash
# Deploy ntfy server
docker run -d \
  --name ntfy \
  -p 80:80 \
  -v /var/cache/ntfy:/var/cache/ntfy \
  binwiederhier/ntfy \
  serve
```

**Integration:**
```elixir
# Send notification to ntfy
def send_mobile_push(user_id, notification) do
  topic = "qlarius-user-#{user_id}"
  
  HTTPoison.post(
    "https://ntfy.qlarius.com/#{topic}",
    Jason.encode!(notification),
    [{"Content-Type", "application/json"}]
  )
end
```

**Cost:** ~$5-10/month for small VPS

### Option B: Direct APNs/FCM Integration

**Library:** `pigeon` (Elixir)

```elixir
# config/runtime.exs
config :pigeon, :apns,
  apns_default: %{
    cert: System.get_env("APNS_CERT_PATH"),
    key: System.get_env("APNS_KEY_PATH"),
    mode: :prod
  }

config :pigeon, :fcm,
  fcm_default: %{
    key: System.get_env("FCM_SERVER_KEY")
  }

# Send iOS notification
def send_apns(device_token, notification) do
  n = Pigeon.APNS.Notification.new(notification, device_token, "com.qlarius.app")
  Pigeon.APNS.push(n)
end

# Send Android notification
def send_fcm(device_token, notification) do
  n = Pigeon.FCM.Notification.new(device_token, notification)
  Pigeon.FCM.push(n)
end
```

**Cost:** $0 (free tier sufficient for most apps)

---

## Notification Use Cases

### 1. New Ads Available

**Trigger:** After `ReconcileOffersForMeFileWorker` completes  
**Frequency:** Max 1-2 per day  
**Condition:** Only if `wallet_balance == $0`

```elixir
Notifications.send_notification(user_id, :new_ads, %{
  count: 3,
  value: "0.15"
})
```

**Message:**
> "New offers available! 🎯"
> "You have 3 new ads worth $0.15"

---

### 2. Wallet Activity

**Trigger:** After ad completion or referral payout  
**Frequency:** Immediate  
**Condition:** Always send

```elixir
Notifications.send_notification(user_id, :wallet_activity, %{
  amount: "0.05",
  source: "ad_completion"
})
```

**Message:**
> "💰 You earned $0.05!"
> "Payment processed"

---

### 3. MeFile Reminder

**Trigger:** Weekly Oban job  
**Frequency:** Once per week  
**Condition:** If `tag_count < 4`

```elixir
Notifications.send_notification(user_id, :reminder, %{
  message: "Complete your MeFile for better offers",
  tags_needed: 2
})
```

**Message:**
> "Complete your MeFile for better offers"
> "Add 2 more tags to unlock premium ads"

---

### 4. Re-engagement

**Trigger:** Daily Oban job checking inactive users  
**Frequency:** Once per month max  
**Condition:** No activity for 7+ days

```elixir
Notifications.send_notification(user_id, :engagement, %{
  message: "Miss you! New ads waiting",
  days_away: 10
})
```

**Message:**
> "Miss you! New ads waiting ⏰"
> "Check out what's new"

---

## Best Practices

### Do's ✅

1. **Respect User Preferences**
   - Always check before sending
   - Honor quiet hours
   - Allow granular control

2. **Rate Limiting**
   - Max 3 notifications per day per user
   - Space them out (min 2 hours apart)
   - Track frequency in DB

3. **Actionable Content**
   - Include deep link to relevant page
   - Clear call-to-action
   - Relevant emoji for personality

4. **Track Everything**
   - Log all sends/deliveries/clicks
   - Build analytics dashboard
   - A/B test messaging

5. **Handle Failures**
   - Remove inactive subscriptions
   - Retry with exponential backoff
   - Fall back to SMS if critical

### Don'ts ❌

1. **Never Spam**
   - Avoid marketing fluff
   - Don't send at 3am (unless user preference)
   - No duplicate notifications

2. **Don't Assume Delivery**
   - Users may revoke permission
   - Browsers can fail silently
   - Always log attempts

3. **Don't Store Sensitive Data**
   - Notification content can be logged
   - Keep PII out of messages
   - Use deep links instead of data

---

## User Preferences UI

### Settings Page Structure

```
Notification Settings
├── Web Push Notifications
│   ├── [Toggle] Enable browser notifications
│   ├── Categories
│   │   ├── [✓] New ads available
│   │   ├── [✓] Wallet activity
│   │   ├── [✓] MeFile reminders
│   │   └── [ ] Re-engagement messages
│   └── Quiet Hours: 10:00 PM - 8:00 AM
│
├── SMS Notifications (Carrier rates may apply)
│   ├── [Toggle] Enable SMS notifications
│   └── Categories
│       ├── [ ] High-priority only
│       └── [ ] Account security alerts
│
└── Mobile Push (Coming Soon)
```

### LiveView Implementation

```elixir
# lib/qlarius_web/live/settings/notifications_live.ex
defmodule QlariusWeb.Settings.NotificationsLive do
  use QlariusWeb, :live_view

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    preferences = Qlarius.Notifications.get_preferences(user_id)
    subscriptions = Qlarius.Notifications.get_active_subscriptions(user_id)

    {:ok,
     socket
     |> assign(:preferences, preferences)
     |> assign(:has_web_push, Enum.any?(subscriptions))
     |> assign(:title, "Notification Settings")}
  end

  def handle_event("toggle_preference", %{"channel" => channel, "category" => category}, socket) do
    user_id = socket.assigns.current_scope.user.id
    current = find_preference(socket.assigns.preferences, channel, category)
    
    Qlarius.Notifications.update_preference(
      user_id,
      channel,
      category,
      !current.enabled
    )

    preferences = Qlarius.Notifications.get_preferences(user_id)
    
    {:noreply,
     socket
     |> assign(:preferences, preferences)
     |> put_flash(:info, "Preference updated")}
  end
end
```

---

## Monitoring & Analytics

### Metrics to Track

1. **Delivery Rates**
   - Sent vs Delivered vs Failed
   - By channel and notification type
   - Track subscription decay

2. **Engagement Rates**
   - Click-through rate (CTR)
   - Conversion rate (click → action)
   - Time to click

3. **User Behavior**
   - Opt-in rates
   - Opt-out reasons
   - Preferred channels

4. **Performance**
   - Notification latency
   - Queue depth
   - Failed sends by reason

### Analytics Queries

```elixir
# Get delivery rate for last 30 days
def get_delivery_rate(days_back \\ 30) do
  since = DateTime.utc_now() |> DateTime.add(-days_back, :day)

  from(l in Log,
    where: l.sent_at > ^since,
    select: %{
      sent: count(l.id),
      delivered: count(l.delivered_at),
      rate: fragment("ROUND(COUNT(?) * 100.0 / COUNT(?), 2)", l.delivered_at, l.id)
    }
  )
  |> Repo.one()
end

# Get top performing notification types
def get_best_performers(limit \\ 5) do
  from(l in Log,
    where: not is_nil(l.clicked_at),
    group_by: l.notification_type,
    select: %{
      type: l.notification_type,
      clicks: count(l.id),
      ctr: fragment("ROUND(COUNT(?)*100.0/COUNT(?), 2)", l.clicked_at, l.id)
    },
    order_by: [desc: count(l.clicked_at)],
    limit: ^limit
  )
  |> Repo.all()
end
```

---

## Cost Analysis

### Phase 1 (Web Push Only)

```
Infrastructure:      $0 (existing Phoenix server)
web_push_encryption: $0 (free library)
Database storage:    ~$0 (minimal)
Bandwidth:          ~$0 (tiny payload)

Total: $0/month
```

### Phase 2 (Add SMS)

```
Twilio SMS:         $0.0075 per message (US)
Example:
  - 1,000 users
  - 2 SMS/month each (high-priority only)
  - 2,000 messages × $0.0075 = $15/month

Total: ~$15-50/month depending on usage
```

### Phase 3 (Add Mobile)

**Option A (ntfy):**
```
Digital Ocean Droplet: $6/month (1GB RAM)
or
Hetzner VPS:          €4/month (~$5)

Total: +$5-6/month
```

**Option B (APNs/FCM Direct):**
```
APNs: Free
FCM:  Free (1M messages/month)

Total: $0/month
```

### Scaling Considerations

```
At 10k users:
- Web Push:     $0
- SMS (limited): $50-100/month
- Mobile:       $0-10/month

At 100k users:
- Web Push:     $0-20/month (slight infra bump)
- SMS (limited): $500/month
- Mobile:       $10-20/month

Still dramatically cheaper than OneSignal ($199-999/month)
```

---

## Security Considerations

### VAPID Keys
- Generate once, store securely
- Never expose private key
- Rotate annually

### Subscription Data
- Store encrypted if sensitive
- Validate endpoints before sending
- Clean up stale subscriptions

### Content
- Don't include PII in notification body
- Use deep links for details
- Log carefully (GDPR compliance)

### Rate Limiting
- Prevent notification bombing
- Track per-user send frequency
- Implement cooldown periods

---

## Migration Path

### Step 1: Setup (Week 1)
- [ ] Add `web_push_encryption` to deps
- [ ] Generate VAPID keys
- [ ] Create database migrations
- [ ] Build Notifications context

### Step 2: Frontend (Week 1-2)
- [ ] Add JS notification hooks
- [ ] Update Service Worker
- [ ] Build settings UI
- [ ] Test on Chrome/Firefox/Safari

### Step 3: Integration (Week 2)
- [ ] Add to Oban jobs
- [ ] Create notification triggers
- [ ] Test delivery pipeline
- [ ] Monitor logs

### Step 4: Polish (Week 3)
- [ ] Add analytics dashboard
- [ ] Fine-tune messaging
- [ ] A/B test notifications
- [ ] Document for team

### Step 5: Scale (Ongoing)
- [ ] Monitor delivery rates
- [ ] Optimize send times
- [ ] Add SMS integration
- [ ] Prepare for mobile apps

---

## Testing Strategy

### Unit Tests
```elixir
# test/qlarius/notifications_test.exs
describe "should_send?/2" do
  test "doesn't send new_ads if user has balance" do
    user = insert(:user, wallet_balance: Decimal.new("1.00"))
    refute Notifications.should_send?(user.id, :new_ads)
  end

  test "respects quiet hours" do
    user = insert(:user)
    insert(:notification_preference,
      user_id: user.id,
      channel: "web_push",
      quiet_hours_start: ~T[22:00:00],
      quiet_hours_end: ~T[08:00:00]
    )
    
    # Test during quiet hours
    # (mock Time.utc_now())
  end
end
```

### Integration Tests
- Test full flow: trigger → send → receive
- Verify subscription management
- Check preference enforcement
- Validate logging

### Manual Testing Checklist
- [ ] Request permission in each browser
- [ ] Receive test notification
- [ ] Click notification → correct page
- [ ] Update preferences → respected
- [ ] Quiet hours → no notifications
- [ ] Unsubscribe → stops sending

---

## Resources

### Documentation
- [Web Push Protocol](https://web.dev/push-notifications-overview/)
- [VAPID Specification](https://datatracker.ietf.org/doc/html/rfc8292)
- [web_push_encryption docs](https://hexdocs.pm/web_push_encryption)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)

### Tools
- [VAPID Key Generator](https://vapidkeys.com/)
- [Push Notification Tester](https://tests.peter.sh/notification-generator/)
- [Service Worker Testing](https://www.pwabuilder.com/)

### Libraries
- [web_push_encryption](https://hex.pm/packages/web_push_encryption) - Elixir
- [pigeon](https://hex.pm/packages/pigeon) - APNs/FCM (future)
- [ex_twilio](https://hex.pm/packages/ex_twilio) - SMS (have)

---

## Questions for Implementation

Before starting, clarify:

1. **VAPID Keys:** Who generates and stores? (DevOps)
2. **Service Worker:** Update existing or create new?
3. **Notification Icon:** What image to use?
4. **Deep Links:** URL structure for notification clicks?
5. **Frequency Limits:** Max notifications per day?
6. **Quiet Hours Default:** 10pm-8am reasonable?
7. **SMS Triggers:** Which notifications warrant SMS?
8. **Analytics Dashboard:** Admin-only or user-facing?

---

## PWA Installation Guide

### Why Install as PWA?

Installing Qlarius as a Progressive Web App provides:
- **Instant Access**: Launch directly from home screen
- **Full-Screen Experience**: Immersive, app-like interface without browser chrome
- **Push Notifications**: Receive alerts for new ads and offers (iOS when installed, Android always)
- **Offline Capability**: View your data even without connection
- **Faster Performance**: Optimized loading and caching
- **Smaller Footprint**: Uses less storage than native apps

### Platform Support

| Feature | iOS (Safari PWA) | Android (Chrome/Edge) | Desktop (Chrome/Edge/Firefox) |
|---------|------------------|----------------------|-------------------------------|
| **Install Prompt** | Manual (Share → Add to Home Screen) | Automatic browser prompt | Automatic browser prompt |
| **Web Push Notifications** | ✅ Yes (when installed as PWA) | ✅ Yes (browser + PWA) | ✅ Yes |
| **Offline Mode** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Full-Screen** | ✅ Yes | ✅ Yes | ⚠️ Window only |
| **Badge Updates** | ❌ No | ✅ Yes | ✅ Yes (some browsers) |
| **Background Sync** | ❌ No | ✅ Yes | ✅ Yes |

### iOS Installation Experience

#### User Flow
1. **Detection**: JavaScript detects iOS Safari (not already installed)
2. **Banner Prompt**: Subtle banner appears at bottom of screen
3. **User Clicks "Install"**: Modal appears with step-by-step instructions
4. **Manual Process**: User follows 3-step guide:
   - Tap Share button (⎙) at bottom center
   - Scroll and select "Add to Home Screen"
   - Tap "Add" to confirm
5. **Success**: App icon appears on home screen
6. **Launch**: Opens in full-screen standalone mode

#### Technical Implementation

**Detection Script** (`assets/js/app.js`):
```javascript
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)
const isPWA = window.navigator.standalone === true
const isIOSSafari = isIOS && !isPWA

if (isIOSSafari && !recentlyDismissed()) {
  showIOSInstallBanner()
}
```

**UI Components** (`lib/qlarius_web/components/pwa_install_prompt.ex`):
- **Install Banner**: Sticky bottom banner with benefits
- **Install Guide Modal**: Step-by-step instructions with visual aids
- **Dismissal Tracking**: 7-day cooldown after user dismisses

**Benefits Messaging**:
- "Get the full mobile experience"
- "Launch instantly from your home screen"
- "Full-screen mode like a native app"
- "Receive push notifications for new ads"
- "Works offline for viewing your data"

#### iOS Limitations
- No programmatic install trigger (requires manual steps)
- Web Push only works when installed as PWA
- No background sync or advanced service worker features
- Notifications less reliable than native iOS apps

### Android Installation Experience

#### User Flow
1. **Detection**: JavaScript detects Android Chrome/Edge
2. **Native Prompt**: Browser automatically shows install prompt
3. **Banner Option**: If dismissed, our banner offers manual trigger
4. **User Clicks "Install"**: Either:
   - **Auto**: Browser's native `beforeinstallprompt` triggers
   - **Manual**: Modal with instructions for browser menu
5. **Success**: App added to home screen and app drawer
6. **Launch**: Opens in full-screen standalone mode

#### Technical Implementation

**BeforeInstallPrompt Handler** (`assets/js/app.js`):
```javascript
let deferredPrompt

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  deferredPrompt = e
  showInstallBanner()
})

function triggerInstall() {
  if (deferredPrompt) {
    deferredPrompt.prompt()
    deferredPrompt.userChoice.then((result) => {
      if (result.outcome === 'accepted') {
        markPWAInstalled()
      }
      deferredPrompt = null
    })
  }
}
```

**Installation Success Detection**:
```javascript
window.addEventListener('appinstalled', () => {
  pushEvent("pwa_installed", {})
  hideInstallPrompts()
})
```

**UI Components**:
- **Install Banner**: Bottom sticky with "Install App" CTA
- **Native Prompt**: Browser's built-in install dialog
- **Fallback Modal**: Manual instructions if prompt unavailable

**Benefits Messaging**:
- "Transform your browser experience into a fast, native-feeling app"
- "Launch directly from your home screen"
- "Immersive full-screen experience"
- "Instant notifications for new offers"
- "Faster performance, smaller storage"

#### Android Advantages
- One-click install via native prompt
- Web Push works in browser + PWA
- Background sync and advanced features
- App shortcuts and widgets support
- Better notification reliability

### Desktop Installation Experience

#### User Flow
1. **Detection**: JavaScript detects desktop browser with PWA support
2. **Install Icon**: Browser shows install icon in address bar
3. **Banner Option**: Subtle prompt appears on first visit
4. **User Clicks "Install"**: Native browser prompt appears
5. **Success**: App added to:
   - Windows: Start menu + desktop
   - macOS: Applications folder + dock
   - Linux: App launcher
6. **Launch**: Opens in dedicated window (not full-screen)

#### Benefits Messaging
- "Install for quick access from your desktop"
- "Open in dedicated window"
- "Stay signed in automatically"
- "Receive desktop notifications"

### Implementation Details

#### Database Schema
```elixir
# Migration: 20260106210242_add_pwa_fields_to_users.exs
alter table(:users) do
  add :pwa_installed, :boolean, default: false
  add :pwa_installed_at, :utc_datetime
  add :pwa_install_dismissed_at, :utc_datetime
end

create index(:users, [:pwa_installed])
```

#### User Schema
```elixir
# lib/qlarius/accounts/user.ex
schema "users" do
  field :pwa_installed, :boolean, default: false
  field :pwa_installed_at, :utc_datetime
  field :pwa_install_dismissed_at, :utc_datetime
  # ...
end
```

#### LiveView Hook
```elixir
# lib/qlarius_web/live/pwa_install_hooks.ex
defmodule QlariusWeb.PWAInstallHooks do
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:show_install_banner, false)
     |> assign(:show_ios_guide, false)
     |> assign(:show_android_guide, false)
     |> attach_hook(:pwa_install_events, :handle_event, &handle_pwa_events/3)}
  end

  defp handle_pwa_events("check_pwa_state", params, socket) do
    # Detect platform and show appropriate prompt
  end

  defp handle_pwa_events("pwa_installed", _params, socket) do
    mark_pwa_installed(user_id)
    {:halt, socket |> put_flash(:info, "🎉 Welcome to the Qlarius app!")}
  end
end
```

#### Triggering Logic

**Show Install Prompt When**:
- User is on mobile (iOS Safari or Android Chrome/Edge)
- User is NOT already running as PWA
- User has not dismissed within last 7 days
- User is authenticated

**Don't Show When**:
- Already installed as PWA
- Desktop browser (unless explicitly requested)
- Dismissed within 7 days
- User not logged in

**Smart Timing**:
- Initial mount: Check state, prepare prompt
- After 3 seconds: Show banner (if conditions met)
- On engagement: Higher priority (e.g., after enabling notifications)
- Never block: Always dismissible

#### Dismissal Strategy
```elixir
defp recently_dismissed?(user_id) do
  case Repo.get(User, user_id) do
    %{pwa_install_dismissed_at: nil} -> false
    %{pwa_install_dismissed_at: dismissed_at} ->
      DateTime.diff(DateTime.utc_now(), dismissed_at, :day) < 7
  end
end
```

#### Install Detection
```javascript
// Detect if already running as PWA
const isPWA = window.matchMedia('(display-mode: standalone)').matches ||
              window.navigator.standalone === true

// On app launch, check and report
if (isPWA) {
  pushEvent("pwa_installed", {})
}
```

### Best Practices

#### UX Guidelines
1. **Non-Intrusive**: Banner at bottom, never full-page takeover
2. **Value-Focused**: Explain benefits clearly ("notifications", "full-screen")
3. **Respectful**: Honor dismissal for 7 days
4. **Clear Instructions**: Step-by-step for iOS manual process
5. **Visual Aids**: Icons, illustrations, or GIFs for complex steps

#### Messaging Tone
- **Welcoming**: "Get the full experience"
- **Benefit-Driven**: "Instant access + notifications"
- **Action-Oriented**: "Install now" not "Learn more"
- **Reassuring**: "You can always install later"

#### Timing Strategy
- **First Visit**: Wait 3-5 seconds, show subtle banner
- **Return Visits**: Show after engagement (e.g., completing first ad)
- **Post-Feature**: After enabling notifications or completing task
- **Never**: On error pages, during forms, or in critical flows

#### Accessibility
- Keyboard navigable install process
- Screen reader friendly instructions
- High contrast mode support
- Clear focus indicators

### Analytics & Tracking

**Track These Events**:
```elixir
# lib/qlarius/analytics/pwa_events.ex
:pwa_banner_shown
:pwa_banner_dismissed
:pwa_ios_guide_opened
:pwa_android_guide_opened
:pwa_install_completed
:pwa_launch_detected
```

**Metrics to Monitor**:
- Install conversion rate (banner impressions → installs)
- Platform breakdown (iOS vs Android vs Desktop)
- Time to install (first visit → installation)
- Dismissal rate
- 7-day return rate for dismissed users
- Notification opt-in rate (PWA vs browser)

### Troubleshooting

#### iOS Issues
**Problem**: User can't find "Add to Home Screen"
- **Solution**: Update instructions to mention scrolling in share menu

**Problem**: Installed PWA not showing web push notifications
- **Solution**: Verify service worker registration and notification permission prompt

**Problem**: PWA opens in Safari instead of standalone
- **Solution**: User must reinstall; check `display: standalone` in manifest

#### Android Issues
**Problem**: `beforeinstallprompt` not firing
- **Solution**: Check manifest validity, HTTPS requirement, service worker registration

**Problem**: Install banner shows every time
- **Solution**: Verify dismissal tracking in localStorage/database

**Problem**: Notifications not working after install
- **Solution**: Prompt for notification permission again in PWA context

### Future Enhancements

1. **App Shortcuts** (Android): Quick actions from long-press icon
2. **Share Target** (Android): Receive shares from other apps
3. **Badge API**: Unread count on app icon
4. **Periodic Background Sync**: Auto-refresh data when connected
5. **File Handler**: Open specific file types
6. **Custom Install Prompt**: A/B test messaging and timing

---

## Support

For implementation questions:
- Technical: Review this doc + web_push_encryption docs
- UX: A/B test notification copy
- Scaling: Monitor delivery rates, adjust infrastructure

---

**End of Document**

*Ready to implement when needed. All components are privacy-first and keep data sovereignty with Qlarius.*

