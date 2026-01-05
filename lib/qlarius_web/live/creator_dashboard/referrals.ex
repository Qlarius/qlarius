defmodule QlariusWeb.CreatorDashboard.Referrals do
  use QlariusWeb, :live_view

  alias Qlarius.Referrals
  alias Qlarius.Creators

  def mount(%{"id" => creator_id}, _session, socket) do
    creator = Creators.get_creator!(creator_id)
    referred_users = Referrals.list_referrals_for_referrer("creator", creator.id)

    my_referral_code =
      creator.referral_code || Referrals.generate_referral_code("creator")

    total_paid =
      Enum.reduce(referred_users, Decimal.new("0.00"), fn user, acc ->
        Decimal.add(acc, user.total_paid)
      end)

    total_pending =
      Enum.reduce(referred_users, 0, fn user, acc ->
        acc + user.pending_clicks
      end)

    socket =
      socket
      |> assign(:page_title, "Referrals - #{creator.name}")
      |> assign(:creator, creator)
      |> assign(:referred_users, referred_users)
      |> assign(:my_referral_code, my_referral_code)
      |> assign(:total_paid, total_paid)
      |> assign(:total_pending, total_pending)

    {:ok, socket}
  end

  def handle_event("copy_code", _params, socket) do
    {:noreply, put_flash(socket, :info, "Referral code copied to clipboard!")}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-3xl font-bold dark:text-white">
          Referrals - {@creator.name}
        </h1>
        <.link navigate={~p"/creators/#{@creator.id}"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="h-5 w-5" /> Back to Creator
        </.link>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Total Referred</div>
            <div class="stat-value text-primary">{length(@referred_users)}</div>
            <div class="stat-desc">Active referrals</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Total Paid</div>
            <div class="stat-value text-success">${Decimal.to_string(@total_paid, :normal)}</div>
            <div class="stat-desc">All-time earnings</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Pending Clicks</div>
            <div class="stat-value text-warning">{@total_pending}</div>
            <div class="stat-desc">Awaiting Friday payout</div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 shadow-xl mb-6">
        <div class="card-body">
          <h2 class="card-title">Your Referral Code</h2>
          <p class="text-sm text-base-content/70">
            Share this code to earn $0.01 for each ad completed by referred users for their first year.
          </p>
          <div class="flex gap-2 mt-4">
            <input
              type="text"
              value={@my_referral_code}
              readonly
              class="input input-bordered flex-1 font-mono"
            />
            <button
              phx-click="copy_code"
              class="btn btn-primary"
              data-clipboard-text={@my_referral_code}
            >
              Copy
            </button>
          </div>
        </div>
      </div>

      <%= if Enum.any?(@referred_users) do %>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Referred Users</h2>
            <div class="overflow-x-auto mt-4">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>Alias</th>
                    <th>Total Clicks</th>
                    <th>Paid Clicks</th>
                    <th>Pending Clicks</th>
                    <th>Total Paid</th>
                    <th>Days Left</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for user <- @referred_users do %>
                    <tr>
                      <td class="font-mono text-sm">{user.alias}</td>
                      <td>{user.total_clicks}</td>
                      <td>{user.paid_clicks}</td>
                      <td>{user.pending_clicks}</td>
                      <td>${Decimal.to_string(user.total_paid, :normal)}</td>
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
      <% else %>
        <div class="alert alert-info">
          <span>No referrals yet. Share your referral code to start earning!</span>
        </div>
      <% end %>
    </div>
    """
  end
end
