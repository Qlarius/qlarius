defmodule QlariusWeb.ReferralsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Referrals
  alias Qlarius.Qlink.Urls
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(_params, session, socket) do
    me_file = socket.assigns.current_scope.user.me_file

    me_file =
      if is_nil(me_file.referral_code) or me_file.referral_code == "" do
        code = Referrals.generate_referral_code("mefile")

        case Referrals.set_referral_code(me_file, code) do
          {:ok, updated_me_file} -> updated_me_file
          {:error, _} -> me_file
        end
      else
        me_file
      end

    if connected?(socket) do
      Qlarius.Wallets.MeFileStatsBroadcaster.subscribe_to_me_file_stats(me_file.id)
    end

    referral = Referrals.get_referral_by_me_file(me_file.id)
    can_add = Referrals.can_add_referral?(me_file.id)

    referred_users =
      if me_file.referral_code do
        Referrals.list_referrals_for_referrer("mefile", me_file.id)
      else
        []
      end

    my_referral_code = me_file.referral_code

    pending_clicks_count =
      Enum.reduce(referred_users, 0, fn user, acc -> acc + user.pending_clicks end)

    total_paid =
      Enum.reduce(referred_users, Decimal.new("0.00"), fn user, acc ->
        Decimal.add(acc, user.total_paid)
      end)

    next_payout_date = calculate_next_friday_midnight()

    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    socket =
      socket
      |> assign(:title, "Referrals")
      |> assign(:current_path, "/referrals")
      |> assign(:current_scope, current_scope)
      |> assign(:me_file, me_file)
      |> assign(:referral, referral)
      |> assign(:can_add_referral, can_add)
      |> assign(:referred_users, referred_users)
      |> assign(:my_referral_code, my_referral_code)
      |> assign(:referral_link_url, Urls.public_app_url("/?ref=#{my_referral_code}"))
      |> assign(:referral_code_input, "")
      |> assign(:referral_error, nil)
      |> assign(:show_referral_form, referral == nil && can_add)
      |> assign(:pending_clicks_count, pending_clicks_count)
      |> assign(:total_paid, total_paid)
      |> assign(:next_payout_date, next_payout_date)
      |> init_pwa_assigns(session)

    {:ok, socket}
  end

  def handle_event("save_referral_code", %{"code" => code}, socket) do
    code = String.trim(code)

    if code == "" do
      {:noreply, assign(socket, :referral_error, "Please enter a referral code")}
    else
      case Referrals.update_referral(socket.assigns.me_file.id, code) do
        {:ok, referral} ->
          {:noreply,
           socket
           |> assign(:referral, referral)
           |> assign(:can_add_referral, false)
           |> assign(:show_referral_form, false)
           |> assign(:referral_error, nil)
           |> put_flash(:info, "Referral code saved successfully!")}

        {:error, :grace_period_expired} ->
          {:noreply,
           socket
           |> assign(:referral_error, "Grace period expired. Cannot add referral code.")
           |> assign(:can_add_referral, false)
           |> assign(:show_referral_form, false)}

        {:error, :not_found} ->
          {:noreply, assign(socket, :referral_error, "Invalid referral code")}

        {:error, changeset} ->
          error_msg =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, assign(socket, :referral_error, error_msg)}
      end
    end
  end

  def handle_event("copy_success", _params, socket) do
    {:noreply, put_flash(socket, :info, "Referral code copied to clipboard!")}
  end

  def handle_event("confirm_payout", _params, socket) do
    me_file = socket.assigns.me_file
    Referrals.process_referrer_payout("mefile", me_file.id)

    referred_users =
      if me_file.referral_code do
        Referrals.list_referrals_for_referrer("mefile", me_file.id)
      else
        []
      end

    pending_clicks_count =
      Enum.reduce(referred_users, 0, fn user, acc -> acc + user.pending_clicks end)

    total_paid =
      Enum.reduce(referred_users, Decimal.new("0.00"), fn user, acc ->
        Decimal.add(acc, user.total_paid)
      end)

    {:noreply,
     socket
     |> assign(:referred_users, referred_users)
     |> assign(:pending_clicks_count, pending_clicks_count)
     |> assign(:total_paid, total_paid)}
  end

  defp calculate_next_friday_midnight do
    now = DateTime.utc_now()
    days_until_friday = rem(7 - Date.day_of_week(DateTime.to_date(now)) + 5, 7)
    days_until_friday = if days_until_friday == 0, do: 7, else: days_until_friday

    now
    |> DateTime.add(days_until_friday, :day)
    |> DateTime.to_date()
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  # Wallet balance: `WalletBalanceSyncHooks` (global on_mount).

  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <Layouts.mobile {assigns}>
        <div class="mx-auto flex max-w-2xl flex-col gap-6">
          <.surface_panel>
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-base-content/50">
                  Lifetime Referral Earnings
                </p>
                <p class="mt-1 text-3xl font-bold tracking-tight text-base-content">
                  ${Decimal.to_string(@total_paid, :normal)}
                </p>
                <p class="mt-1 text-sm text-base-content/60">
                  From {referral_count_display(length(@referred_users), :description)}
                </p>
              </div>
              <.icon name="hero-user-group" class="h-10 w-10 shrink-0 text-primary opacity-90" />
            </div>
          </.surface_panel>

          <div>
            <h2 class={referrals_section_heading_classes()}>Share</h2>
            <.surface_panel>
              <h3 class={referrals_panel_title_classes()}>Your Referral Link</h3>
              <p class="text-sm text-base-content/70">
                Share this link with friends. You'll earn $0.01 for each ad they complete for the first year!
              </p>
              <div class="mt-4 space-y-3">
                <div class="flex w-full flex-col gap-3">
                  <input
                    id="referral-link-input"
                    type="text"
                    value={@referral_link_url}
                    readonly
                    class="input input-bordered w-full min-h-12 bg-base-100 px-4 py-3.5 font-mono text-sm dark:bg-black"
                  />
                  <button
                    phx-hook="CopyToClipboard"
                    id="copy-referral-link-btn"
                    data-target="referral-link-input"
                    class="btn btn-primary btn-block min-h-14 w-full rounded-full py-3.5"
                  >
                    Copy Link
                  </button>
                </div>
                <div class={"collapse collapse-arrow #{referrals_inset_panel_classes()}"}>
                  <input type="checkbox" />
                  <div class="collapse-title min-h-0 py-3 text-xs font-medium">
                    Just the code: {@my_referral_code}
                  </div>
                  <div class="collapse-content">
                    <p class="pb-3 text-xs text-base-content/60">
                      Use this code if someone needs to enter it manually.
                    </p>
                  </div>
                </div>
              </div>
            </.surface_panel>
          </div>

          <%= if @show_referral_form do %>
            <div>
              <h2 class={referrals_section_heading_classes()}>Referrer</h2>
              <.surface_panel>
                <h3 class={referrals_panel_title_classes()}>Add Your Referrer</h3>
                <p class="text-sm text-base-content/70">
                  If someone referred you, enter their code here within 10 days of registration.
                </p>
                <%= if @referral_error do %>
                  <div class="alert alert-error mt-3">
                    <span>{@referral_error}</span>
                  </div>
                <% end %>
                <form phx-submit="save_referral_code" class="mt-4">
                  <input
                    type="text"
                    name="code"
                    placeholder="Enter referral code"
                    value={@referral_code_input}
                    class="input input-bordered w-full bg-base-100 dark:bg-black"
                    required
                  />
                  <div class="mt-4 flex justify-end">
                    <button type="submit" class="btn btn-primary rounded-full">
                      Save Referral Code
                    </button>
                  </div>
                </form>
              </.surface_panel>
            </div>
          <% end %>

          <%= if @referral do %>
            <div>
              <h2 class={referrals_section_heading_classes()}>Referrer</h2>
              <.surface_panel>
                <h3 class={referrals_panel_title_classes()}>Your Referrer</h3>
                <p class="text-base-content/80">
                  You were referred by:
                  <span class="font-semibold">
                    <%= if referrer_alias = Map.get(@referral, :referrer_alias) do %>
                      {referrer_alias}
                    <% else %>
                      {String.capitalize(@referral.referrer_type)}
                    <% end %>
                  </span>
                </p>
                <p class="mt-1 text-sm text-base-content/60">
                  Expires: {Calendar.strftime(@referral.expires_at, "%B %d, %Y")}
                </p>
              </.surface_panel>
            </div>
          <% end %>

          <%= if !@can_add_referral && @referral == nil do %>
            <div>
              <h2 class={referrals_section_heading_classes()}>Referrer</h2>
              <.surface_panel>
                <h3 class={referrals_panel_title_classes()}>Add Your Referrer</h3>
                <p class="text-sm text-base-content/70">
                  10-day grace period has expired. You cannot add a referrer at this time.
                </p>
                <div class="mt-4 flex flex-col gap-2 sm:flex-row">
                  <input
                    type="text"
                    placeholder="Enter referral code"
                    class="input input-bordered flex-1 bg-base-100 dark:bg-black"
                    disabled
                  />
                  <button type="button" class="btn btn-primary shrink-0 rounded-full" disabled>
                    Save Referral Code
                  </button>
                </div>
              </.surface_panel>
            </div>
          <% end %>

          <%= if @pending_clicks_count > 0 do %>
            <.surface_panel class="border-t-primary dark:border-t-primary">
              <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div class="min-w-0">
                  <h3 class={referrals_panel_title_classes()}>Pending Referral Payout</h3>
                  <p class="mt-1 text-sm text-base-content/70">
                    You have <span class="font-bold text-primary">{@pending_clicks_count}</span>
                    pending clicks ready for payout
                    (<span class="font-bold">${Decimal.to_string(Decimal.mult(Decimal.new("0.01"), @pending_clicks_count), :normal)}</span>)
                  </p>
                  <p class="mt-2 text-xs text-base-content/60">
                    Next automatic payout:
                    <span class="font-semibold">
                      {Calendar.strftime(@next_payout_date, "%B %d, %Y at %I:%M %p UTC")}
                    </span>
                  </p>
                </div>
                <button phx-click={show_modal("payout-modal")} class="btn btn-primary shrink-0 rounded-full">
                  Process Now
                </button>
              </div>
            </.surface_panel>
          <% end %>

          <%= if Enum.any?(@referred_users) do %>
            <div>
              <h2 class={referrals_section_heading_classes()}>
                Referred users{referral_count_display(length(@referred_users), :title_suffix)}
              </h2>
              <.surface_panel padding={false} class="overflow-hidden">
                <div class="overflow-x-auto">
                  <table class="table w-full [&_td]:px-4 [&_td]:py-3 [&_th]:px-4 [&_th]:py-3">
                    <thead>
                      <tr class="border-b border-base-300/60 dark:border-base-content/10">
                        <th class="text-base-content/60">Alias</th>
                        <th class="text-base-content/60">Total Paid</th>
                        <th class="text-base-content/60">Pending Clicks</th>
                        <th class="text-base-content/60">Days Left</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for user <- @referred_users do %>
                        <tr class="border-t border-base-300/60 first:border-t-0 dark:border-base-content/10">
                          <td class="font-mono text-sm">{user.alias}</td>
                          <td>${Decimal.to_string(user.total_paid, :normal)}</td>
                          <td>{user.pending_clicks}</td>
                          <td>
                            <%= if user.is_expired do %>
                              <span class="badge badge-ghost">Fulfilled</span>
                            <% else %>
                              <span class="badge badge-success">{user.days_remaining}</span>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </.surface_panel>
            </div>
          <% end %>
        </div>

        <:modals>
          <.modal id="payout-modal">
            <.surface_panel class="max-w-lg">
              <h3 class={referrals_panel_title_classes()}>Confirm Referral Payout</h3>
              <p class="py-4 text-base-content/80">
                Process <span class="font-bold text-primary">{@pending_clicks_count}</span>
                pending clicks
                for <span class="font-bold text-success">${Decimal.to_string(Decimal.mult(Decimal.new("0.01"), @pending_clicks_count), :normal)}</span>?
              </p>
              <div class="flex flex-wrap justify-end gap-2">
                <button class="btn btn-ghost rounded-full" phx-click={hide_modal("payout-modal")}>
                  Cancel
                </button>
                <button
                  class="btn btn-primary rounded-full"
                  phx-click={JS.push("confirm_payout") |> hide_modal("payout-modal")}
                >
                  Confirm Payout
                </button>
              </div>
            </.surface_panel>
          </.modal>
        </:modals>
      </Layouts.mobile>
    </div>
    """
  end

  # Shared copy for referral counts from `length(@referred_users)`.
  defp referral_count_display(1, :description), do: "1 total referral"

  defp referral_count_display(n, :description) when is_integer(n) and n >= 0,
    do: "#{n} total referrals"

  defp referral_count_display(n, :title_suffix) when is_integer(n) and n >= 0,
    do: " (#{n})"

  defp referrals_section_heading_classes do
    "mb-3 text-lg font-bold tracking-tight text-base-content/50"
  end

  defp referrals_panel_title_classes do
    "text-xl font-bold tracking-tight text-base-content"
  end

  defp referrals_inset_panel_classes do
    "rounded-lg bg-base-200/60 dark:bg-base-300/40"
  end
end
