defmodule QlariusWeb.ReferralsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Referrals
  alias Qlarius.Qlink.Urls
  import QlariusWeb.Money, only: [format_usd: 1]
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
          # Reload so the referrer's masked alias is on the row, as on mount.
          referral = Referrals.get_referral_by_me_file(socket.assigns.me_file.id) || referral

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
    {:noreply, put_flash(socket, :info, "Copied to clipboard")}
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

  # Laid out like Wallet and Builder: a summary card (what referrals have paid,
  # with any pending payout folded in), then labelled sections (your link,
  # your referrer, the people you referred as rows). On wide content
  # (.referrals-board container query) the people list moves into a second
  # column beside the rest.
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :pending_amount,
        Decimal.mult(Decimal.new("0.01"), assigns.pending_clicks_count)
      )

    ~H"""
    <div>
      <Layouts.mobile {assigns}>
        <div class={["referrals-board", @referred_users != [] && "referrals-board--split"]}>
          <div class="referrals-board__cols">
            <div class="referrals-board__main">
              <.surface_panel>
                <div class="flex items-start justify-between gap-4">
                  <div class="min-w-0">
                    <p class="wallet-summary__hero">{format_usd(@total_paid)}</p>
                    <p class="wallet-summary__label">
                      paid from {referral_count_display(length(@referred_users))}
                    </p>
                  </div>
                  <span class="ledger-row__icon is-credit h-11 w-11">
                    <.icon name="hero-user-group" class="h-6 w-6" />
                  </span>
                </div>

                <div :if={@pending_clicks_count > 0} class="referral-pending">
                  <div class="min-w-0">
                    <p class="text-[15px] font-semibold text-base-content tabular-amount">
                      {format_usd(@pending_amount)} pending
                    </p>
                    <p class="mt-0.5 text-[13px] text-base-content/55">
                      {click_count(@pending_clicks_count)} · pays out {Calendar.strftime(
                        @next_payout_date,
                        "%a, %b %-d"
                      )}
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click={show_modal("payout-modal")}
                    class="referral-btn referral-btn--quiet"
                  >
                    Pay out now
                  </button>
                </div>
              </.surface_panel>

              <section>
                <div class="mefile-category__head">
                  <h2>Your link</h2>
                </div>
                <.surface_panel>
                  <p class="text-sm text-base-content/70">
                    When friends join with your link, you get $0.01 for each ad they finish in their first year.
                  </p>
                  <div class="referral-link mt-4">
                    <input
                      id="referral-link-input"
                      type="text"
                      value={@referral_link_url}
                      readonly
                      aria-label="Your referral link"
                      class="referral-link__field"
                    />
                    <button
                      phx-hook="CopyToClipboard"
                      id="copy-referral-link-btn"
                      data-target="referral-link-input"
                      data-copied-label="Copied"
                      class="referral-btn"
                    >
                      <.icon name="hero-link" class="h-4 w-4" />
                      <span data-copy-label>Copy</span>
                    </button>
                  </div>
                  <div class="referral-code">
                    <span class="text-sm text-base-content/55">Or share the code</span>
                    <span id="referral-code-text" class="font-semibold text-base-content">
                      {@my_referral_code}
                    </span>
                    <button
                      phx-hook="CopyToClipboard"
                      id="copy-referral-code-btn"
                      data-target="referral-code-text"
                      data-copied-label="Copied"
                      class="referral-btn referral-btn--quiet referral-btn--sm ml-auto"
                    >
                      <span data-copy-label>Copy</span>
                    </button>
                  </div>
                </.surface_panel>
              </section>

              <section>
                <div class="mefile-category__head">
                  <h2>Your referrer</h2>
                </div>
                <.surface_panel>
                  <%= cond do %>
                    <% @referral -> %>
                      <p class="text-[15px] text-base-content">
                        Referred by
                        <span class="font-semibold">
                          <%= if referrer_alias = Map.get(@referral, :referrer_alias) do %>
                            {referrer_alias}
                          <% else %>
                            {String.capitalize(@referral.referrer_type)}
                          <% end %>
                        </span>
                      </p>
                      <p class="mt-0.5 text-[13px] text-base-content/55">
                        Until {Calendar.strftime(@referral.expires_at, "%b %-d, %Y")}
                      </p>
                    <% @show_referral_form -> %>
                      <p class="text-sm text-base-content/70">
                        Did someone refer you? Enter their code within 10 days of joining.
                      </p>
                      <form phx-submit="save_referral_code" class="referral-link mt-4">
                        <input
                          type="text"
                          name="code"
                          placeholder="Referral code"
                          value={@referral_code_input}
                          aria-label="Referral code"
                          class="referral-link__field"
                          required
                        />
                        <button type="submit" class="referral-btn">Save</button>
                      </form>
                      <p :if={@referral_error} class="mt-2 text-sm text-error">{@referral_error}</p>
                    <% true -> %>
                      <p class="text-sm text-base-content/60">
                        The 10 days to add a referrer have passed.
                      </p>
                  <% end %>
                </.surface_panel>
              </section>
            </div>

            <section :if={@referred_users != []}>
              <div class="mefile-category__head">
                <h2>People you referred</h2>
                <span class="tabular-amount">{length(@referred_users)}</span>
              </div>
              <.surface_panel padding={false}>
                <ul class="ledger-list">
                  <li :for={user <- @referred_users}>
                    <div class="ledger-row is-static">
                      <span class="ledger-row__icon">
                        <.icon name="hero-user" class="h-5 w-5" />
                      </span>
                      <span class="ledger-row__main">
                        <span class="ledger-row__title">{user.alias}</span>
                        <span class="ledger-row__meta">
                          <%= if user.is_expired do %>
                            First year complete
                          <% else %>
                            {days_left(user.days_remaining)}
                          <% end %>
                        </span>
                      </span>
                      <span class="ledger-row__amounts">
                        <span class={[
                          "ledger-row__amt",
                          if(Decimal.gt?(user.total_paid, 0), do: "is-credit", else: "is-zero")
                        ]}>
                          {format_usd(user.total_paid)}
                        </span>
                        <span :if={user.pending_clicks > 0} class="ledger-row__bal">
                          {user.pending_clicks} pending
                        </span>
                      </span>
                    </div>
                  </li>
                </ul>
              </.surface_panel>
            </section>
          </div>
        </div>

        <:modals>
          <.modal id="payout-modal" on_cancel={hide_modal("payout-modal")}>
            <div class="max-w-md p-6">
              <h3 class="text-xl font-bold text-base-content">Pay out now?</h3>
              <p class="mt-2 text-base-content/70">
                Add
                <span class="font-semibold text-base-content tabular-amount">
                  {format_usd(@pending_amount)}
                </span>
                from {click_count(@pending_clicks_count)} to your wallet now, instead of at Friday's payout.
              </p>
              <div class="mt-6 flex flex-wrap justify-end gap-2">
                <button class="btn btn-ghost rounded-full" phx-click={hide_modal("payout-modal")}>
                  Cancel
                </button>
                <button
                  class="btn btn-primary rounded-full"
                  phx-click={JS.push("confirm_payout") |> hide_modal("payout-modal")}
                >
                  Pay out <span class="tabular-amount">{format_usd(@pending_amount)}</span>
                </button>
              </div>
            </div>
          </.modal>
        </:modals>
      </Layouts.mobile>
    </div>
    """
  end

  defp referral_count_display(1), do: "1 referral"
  defp referral_count_display(n), do: "#{n} referrals"

  defp click_count(1), do: "1 click"
  defp click_count(n), do: "#{n} clicks"

  defp days_left(1), do: "1 day left"
  defp days_left(n), do: "#{n} days left"
end
