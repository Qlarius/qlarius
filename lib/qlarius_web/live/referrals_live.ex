defmodule QlariusWeb.ReferralsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Referrals

  def mount(_params, _session, socket) do
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
      |> assign(:referral_code_input, "")
      |> assign(:referral_error, nil)
      |> assign(:show_referral_form, referral == nil && can_add)
      |> assign(:pending_clicks_count, pending_clicks_count)
      |> assign(:total_paid, total_paid)
      |> assign(:next_payout_date, next_payout_date)

    {:ok, socket}
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

  def handle_event("show_payout_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_payout", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("confirm_payout", _params, socket) do
    result = Referrals.process_referrer_payout("mefile", socket.assigns.me_file.id)

    case result do
      {:ok, :no_pending_clicks} ->
        {:noreply,
         socket
         |> put_flash(:info, "No pending clicks to process.")
         |> push_navigate(to: ~p"/referrals")}

      {:ok, %{clicks: clicks, amount: amount}} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Successfully processed #{clicks} clicks for $#{Decimal.to_string(amount, :normal)}!"
         )
         |> push_navigate(to: ~p"/referrals")}

      {:error, :no_ledger} ->
        {:noreply,
         socket
         |> put_flash(:error, "Wallet not found. Please contact support.")
         |> push_navigate(to: ~p"/referrals")}

      {:error, {step, changeset}} ->
        require Logger
        Logger.error("Referral payout failed at step #{step}: #{inspect(changeset.errors)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to process payout. Please try again.")
         |> push_navigate(to: ~p"/referrals")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to process payout. Please try again.")
         |> push_navigate(to: ~p"/referrals")}
    end
  end

  def handle_info({:me_file_balance_updated, new_balance}, socket) do
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <div class="container mx-auto px-4 py-6 max-w-3xl">
        <div class="space-y-6">
          <div class="stats shadow-xl bg-primary text-primary-content w-full">
            <div class="stat">
              <div class="stat-figure text-primary-content">
                <.icon name="hero-user-group" class="w-10 h-10" />
              </div>
              <div class="stat-title text-primary-content/70">Lifetime Referral Earnings</div>
              <div class="stat-value text-3xl">
                ${Decimal.to_string(@total_paid, :normal)}
              </div>
              <div class="stat-desc text-primary-content/60">
                Total paid from all referrals
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="card bg-base-200 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Your Referral Code</h2>
                <p class="text-sm text-base-content/70">
                  Share this code with friends. You'll earn $0.01 for each ad they complete for the first year!
                </p>
                <div class="flex gap-2 mt-4">
                  <input
                    id="referral-code-input"
                    type="text"
                    value={@my_referral_code}
                    readonly
                    class="input input-bordered flex-1 font-mono"
                  />
                  <button
                    phx-hook="CopyToClipboard"
                    id="copy-referral-code-btn"
                    data-target="referral-code-input"
                    class="btn btn-primary"
                  >
                    Copy
                  </button>
                </div>
              </div>
            </div>

            <%= if @show_referral_form do %>
              <div class="card bg-base-200 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title">Add Your Referrer</h2>
                  <p class="text-sm text-base-content/70">
                    If someone referred you, enter their code here within 10 days of registration.
                  </p>
                  <%= if @referral_error do %>
                    <div class="alert alert-error mt-2">
                      <span>{@referral_error}</span>
                    </div>
                  <% end %>
                  <form phx-submit="save_referral_code">
                    <div class="form-control mt-4">
                      <input
                        type="text"
                        name="code"
                        placeholder="Enter referral code"
                        value={@referral_code_input}
                        class="input input-bordered"
                        required
                      />
                    </div>
                    <div class="card-actions justify-end mt-4">
                      <button type="submit" class="btn btn-primary">
                        Save Referral Code
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            <% end %>

            <%= if @referral do %>
              <div class="card bg-base-200 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title">Your Referrer</h2>
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
                  <p class="text-sm text-base-content/60">
                    Expires: {Calendar.strftime(@referral.expires_at, "%B %d, %Y")}
                  </p>
                </div>
              </div>
            <% end %>

            <%= if !@can_add_referral && @referral == nil do %>
              <div class="card bg-base-200 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title">Add Your Referrer</h2>
                  <p class="text-sm text-base-content/70">
                    10-day grace period has expired. You cannot add a referrer at this time.
                  </p>
                  <form>
                    <div class="flex gap-2 mt-4">
                      <input
                        type="text"
                        placeholder="Enter referral code"
                        class="input input-bordered flex-1 !border !border-base-content/30"
                        disabled
                      />
                      <button type="submit" class="btn btn-primary" disabled>
                        Save Referral Code
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @pending_clicks_count > 0 do %>
            <div class="card bg-base-100 shadow-xl border border-primary">
              <div class="card-body">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 class="text-lg font-semibold">Pending Referral Payout</h3>
                    <p class="text-sm text-base-content/70 mt-1">
                      You have <span class="font-bold text-primary">{@pending_clicks_count}</span>
                      pending clicks ready for payout
                      (<span class="font-bold">${Decimal.to_string(Decimal.mult(Decimal.new("0.01"), @pending_clicks_count), :normal)}</span>)
                    </p>
                    <p class="text-xs text-base-content/60 mt-2">
                      Next automatic payout:
                      <span class="font-semibold">
                        {Calendar.strftime(@next_payout_date, "%B %d, %Y at %I:%M %p UTC")}
                      </span>
                    </p>
                  </div>
                  <button phx-click={show_modal("payout-modal")} class="btn btn-primary">
                    Process Now
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <%= if Enum.any?(@referred_users) do %>
            <div class="card bg-base-200 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Users You've Referred</h2>
                <div class="overflow-x-auto mt-4">
                  <table class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>Alias</th>
                        <th>Total Paid</th>
                        <th>Pending Clicks</th>
                        <th>Days Left</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for user <- @referred_users do %>
                        <tr>
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
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <.modal id="payout-modal" show={false}>
        <div class="p-6">
          <h3 class="font-bold text-2xl mb-4">Confirm Referral Payout</h3>
          <p class="text-base mb-4">
            Are you sure you want to process
            <span class="font-bold text-primary">{@pending_clicks_count}</span>
            pending clicks for a total of <span class="font-bold text-success">${Decimal.to_string(Decimal.mult(Decimal.new("0.01"), @pending_clicks_count), :normal)}</span>?
          </p>
          <p class="text-sm text-base-content/70 mb-6">
            This amount will be added to your wallet immediately.
          </p>
          <div class="flex justify-end gap-3">
            <button type="button" phx-click={hide_modal("payout-modal")} class="btn btn-ghost">
              Cancel
            </button>
            <button type="button" phx-click="confirm_payout" class="btn btn-primary">
              Confirm Payout
            </button>
          </div>
        </div>
      </.modal>
    </Layouts.mobile>
    """
  end
end
