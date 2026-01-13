defmodule QlariusWeb.Admin.MeFileInspectorLive.Show do
  use QlariusWeb, :live_view
  import Ecto.Query

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Repo
  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  alias Qlarius.Sponster.{Offer, Offers}
  alias Qlarius.Notifications

  @impl true
  def mount(%{"id" => me_file_id}, _session, socket) do
    me_file_id = String.to_integer(me_file_id)
    me_file = Repo.get!(MeFile, me_file_id) |> Repo.preload(:user)

    {:ok,
     socket
     |> assign(:me_file_id, me_file_id)
     |> assign(:me_file, me_file)
     |> assign_user_details()
     |> assign_tags()
     |> assign_offers()
     |> assign_ledger_entries()
     |> assign_navigation()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "MeFile: #{socket.assigns.me_file.user.alias}")}
  end

  @impl true
  def handle_event("navigate_prev", _params, socket) do
    if socket.assigns.prev_user_id do
      prev_me_file = get_me_file_by_user_id(socket.assigns.prev_user_id)

      {:noreply, push_navigate(socket, to: ~p"/admin/mefile_inspector/#{prev_me_file.id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("navigate_next", _params, socket) do
    if socket.assigns.next_user_id do
      next_me_file = get_me_file_by_user_id(socket.assigns.next_user_id)
      {:noreply, push_navigate(socket, to: ~p"/admin/mefile_inspector/#{next_me_file.id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_test_notification", _params, socket) do
    me_file = socket.assigns.me_file
    user = socket.assigns.user
    offers = socket.assigns.offers
    ad_count = length(offers)

    if ad_count == 0 do
      {:noreply, put_flash(socket, :warning, "⚠️ No active ads for this user")}
    else
      total_value = Offers.total_active_offer_amount(me_file) || Decimal.new(0)
      total_value_float = Decimal.to_float(total_value)

      case Notifications.send_ad_count_notification(user, ad_count, total_value_float) do
        {:ok, :sent} ->
          {:noreply,
           put_flash(
             socket,
             :info,
             "✅ Sent notification: #{ad_count} ads, $#{:erlang.float_to_binary(total_value_float, decimals: 2)}"
           )}

        {:ok, :no_subscriptions} ->
          {:noreply,
           put_flash(socket, :warning, "⚠️ User has no active push subscriptions")}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "❌ Failed to send notification: #{inspect(reason)}")}
      end
    end
  end

  defp get_me_file_by_user_id(user_id) do
    from(mf in MeFile, where: mf.user_id == ^user_id)
    |> Repo.one!()
  end

  defp assign_user_details(socket) do
    me_file = socket.assigns.me_file
    user = me_file.user

    mobile_number_encrypted = user.mobile_number_encrypted
    masked_mobile = mask_phone_number(mobile_number_encrypted)

    home_zip = get_home_zip(me_file.id)

    ledger_header =
      from(lh in LedgerHeader, where: lh.me_file_id == ^me_file.id)
      |> Repo.one()

    wallet_balance = if ledger_header, do: ledger_header.balance, else: Decimal.new("0.00")

    socket
    |> assign(:user, user)
    |> assign(:masked_mobile, masked_mobile)
    |> assign(:home_zip, home_zip)
    |> assign(:wallet_balance, wallet_balance)
    |> assign(:registered_at, user.inserted_at)
    |> assign(:last_sign_in_at, user.last_sign_in_at)
  end

  defp mask_phone_number(nil), do: "N/A"

  defp mask_phone_number(phone) when is_binary(phone) do
    case ExPhoneNumber.parse(phone, "US") do
      {:ok, parsed} ->
        formatted = ExPhoneNumber.format(parsed, :national)

        case Regex.run(~r/\((\d{3})\)\s*(\d{3})-(\d{4})/, formatted) do
          [_, area, _prefix, suffix] ->
            last_two = String.slice(suffix, -2, 2)
            "(#{area}) ###-###{last_two}"

          _ ->
            case String.length(phone) do
              len when len >= 4 ->
                last_two = String.slice(phone, -2, 2)
                "###-###{last_two}"

              _ ->
                "###-####"
            end
        end

      {:error, _} ->
        case String.length(phone) do
          len when len >= 4 ->
            last_two = String.slice(phone, -2, 2)
            "###-###{last_two}"

          _ ->
            "###-####"
        end
    end
  end

  defp get_home_zip(me_file_id) do
    home_zip_trait_id = 4

    from(mft in Qlarius.YouData.MeFiles.MeFileTag,
      join: t in Qlarius.YouData.Traits.Trait,
      on: t.id == mft.trait_id,
      where: mft.me_file_id == ^me_file_id and t.parent_trait_id == ^home_zip_trait_id,
      select: mft.tag_value,
      limit: 1
    )
    |> Repo.one()
  end

  defp assign_tags(socket) do
    me_file_id = socket.assigns.me_file_id
    tag_map = MeFiles.me_file_tag_map_by_category_trait_tag(me_file_id)

    tag_count =
      tag_map
      |> Enum.flat_map(fn {_category, parent_traits} -> parent_traits end)
      |> length()

    socket
    |> assign(:tag_map, tag_map)
    |> assign(:tag_count, tag_count)
  end

  defp assign_offers(socket) do
    offers =
      from(o in Offer,
        where: o.me_file_id == ^socket.assigns.me_file_id and o.is_current == true,
        preload: [media_piece: :ad_category],
        order_by: [desc: o.offer_amt]
      )
      |> Repo.all()

    assign(socket, :offers, offers)
  end

  defp assign_ledger_entries(socket) do
    ledger_entries =
      from(le in LedgerEntry,
        join: lh in LedgerHeader,
        on: lh.id == le.ledger_header_id,
        where: lh.me_file_id == ^socket.assigns.me_file_id,
        order_by: [desc: le.created_at],
        limit: 50,
        select: %{
          id: le.id,
          amt: le.amt,
          description: le.description,
          meta_1: le.meta_1,
          created_at: le.created_at
        }
      )
      |> Repo.all()

    assign(socket, :ledger_entries, ledger_entries)
  end

  defp assign_navigation(socket) do
    current_user_id = socket.assigns.me_file.user_id

    prev_user =
      from(u in User,
        where: u.role == "user" and u.id < ^current_user_id,
        order_by: [desc: u.id],
        limit: 1,
        select: u.id
      )
      |> Repo.one()

    next_user =
      from(u in User,
        where: u.role == "user" and u.id > ^current_user_id,
        order_by: [asc: u.id],
        limit: 1,
        select: u.id
      )
      |> Repo.one()

    socket
    |> assign(:prev_user_id, prev_user)
    |> assign(:next_user_id, next_user)
  end

  defp icon_for_meta_1(nil), do: "hero-cube"
  defp icon_for_meta_1("Tip/Donation"), do: "hero-gift"
  defp icon_for_meta_1("Tiqit Purchase"), do: "hero-ticket"
  defp icon_for_meta_1("Referral Bonus"), do: "hero-user-group"
  defp icon_for_meta_1("Text/Jump"), do: "hero-arrow-right-start-on-rectangle"
  defp icon_for_meta_1("Banner Tap"), do: "hero-photo"
  defp icon_for_meta_1("Video Viewing"), do: "hero-play-circle"
  defp icon_for_meta_1("Gift"), do: "hero-gift"
  defp icon_for_meta_1(_), do: "hero-cube"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <div class="p-6">
              <div class="flex justify-between items-center mb-6">
                <div class="flex items-center gap-4">
                  <.link navigate={~p"/admin/mefile_inspector"} class="btn btn-sm btn-ghost">
                    <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to List
                  </.link>
                  <h1 class="text-2xl font-bold">MeFile Inspector</h1>
                </div>

                <div class="flex gap-2">
                  <button
                    phx-click="send_test_notification"
                    data-confirm="Send a test ad count notification to this user right now?"
                    class="btn btn-sm btn-info"
                    title="Send test ad count notification"
                  >
                    <.icon name="hero-bell-alert" class="w-5 h-5" />
                    Send Test Notification
                  </button>
                  <button
                    phx-click="navigate_prev"
                    disabled={is_nil(@prev_user_id)}
                    class="btn btn-sm btn-outline"
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" /> Previous
                  </button>
                  <button
                    phx-click="navigate_next"
                    disabled={is_nil(@next_user_id)}
                    class="btn btn-sm btn-outline"
                  >
                    Next <.icon name="hero-chevron-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300 mb-6">
                <div class="card-body">
                  <div class="flex justify-between items-start">
                    <div class="space-y-2">
                      <h2 class="text-3xl font-bold">{@user.alias}</h2>
                      <div class="flex items-center gap-6 text-sm">
                        <div class="flex items-center gap-2">
                          <.icon name="hero-phone" class="w-4 h-4 text-base-content/60" />
                          <span class="font-mono">{@masked_mobile}</span>
                        </div>
                        <div :if={@home_zip} class="flex items-center gap-2">
                          <.icon name="hero-map-pin" class="w-4 h-4 text-primary" />
                          <span class="font-semibold text-primary text-lg">📍 {@home_zip}</span>
                        </div>
                      </div>
                      <div class="flex items-center gap-4 text-xs text-base-content/60">
                        <div>
                          Registered: {Calendar.strftime(@registered_at, "%m/%d/%Y %I:%M %p")}
                        </div>
                        <div :if={@last_sign_in_at}>
                          Last Sign-in: {Calendar.strftime(@last_sign_in_at, "%m/%d/%Y %I:%M %p")}
                        </div>
                      </div>
                    </div>

                    <div class="stats shadow-sm bg-base-200 border border-base-300">
                      <div class="stat py-3 px-4">
                        <div class="stat-title text-xs">Wallet Balance</div>
                        <div class="stat-value text-2xl">
                          {QlariusWeb.Money.format_usd(@wallet_balance)}
                        </div>
                      </div>
                      <div class="stat py-3 px-4">
                        <div class="stat-title text-xs">Tags</div>
                        <div class="stat-value text-2xl">{@tag_count}</div>
                      </div>
                      <div class="stat py-3 px-4">
                        <div class="stat-title text-xs">Active Offers</div>
                        <div class="stat-value text-2xl">{length(@offers)}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
                <div class="card bg-base-100 border border-base-300">
                  <div class="card-body">
                    <h3 class="card-title flex items-center gap-2">
                      <.icon name="hero-tag" class="w-5 h-5" /> Tags ({@tag_count})
                    </h3>

                    <div :if={@tag_count == 0} class="text-center py-12">
                      <.icon name="hero-tag" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
                      <p class="text-lg font-medium text-base-content/70">No tags yet</p>
                    </div>

                    <div :if={@tag_count > 0} class="space-y-6">
                      <div :for={{{_id, name, _display_order}, parent_traits} <- @tag_map}>
                        <div class="flex flex-row justify-between items-baseline mb-3">
                          <h4 class="text-lg font-medium">{name}</h4>
                          <span class="text-sm text-gray-500">
                            {length(parent_traits)} tags
                          </span>
                        </div>

                        <div class="flex flex-row flex-wrap gap-3">
                          <QlariusWeb.Components.TraitComponents.trait_card
                            :for={
                              {parent_trait_id, parent_trait_name, _parent_trait_display_order,
                               tags_traits} <-
                                parent_traits
                            }
                            parent_trait_id={parent_trait_id}
                            parent_trait_name={parent_trait_name}
                            tags_traits={tags_traits}
                            clickable={false}
                            editable={false}
                          />
                        </div>

                        <div class="mt-4 border-b border-neutral-300 dark:border-neutral-500"></div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="card bg-base-100 border border-base-300">
                  <div class="card-body">
                    <h3 class="card-title flex items-center gap-2">
                      <.icon name="hero-megaphone" class="w-5 h-5" />
                      Active Offers ({length(@offers)})
                    </h3>

                    <div :if={@offers == []} class="text-center py-12">
                      <.icon
                        name="hero-megaphone"
                        class="w-16 h-16 mx-auto text-base-content/30 mb-4"
                      />
                      <p class="text-lg font-medium text-base-content/70">No active offers</p>
                    </div>

                    <div :if={@offers != []} class="space-y-4">
                      <div :for={offer <- @offers}>
                        <QlariusWeb.Components.AdsComponents.three_tap_ad
                          media_piece={offer.media_piece}
                          show_banner={true}
                        />
                        <div class="text-xs text-base-content/60 mt-1 flex justify-between">
                          <span>Offer: {QlariusWeb.Money.format_usd(offer.offer_amt)}</span>
                          <span>Campaign ID: {offer.campaign_id}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h3 class="card-title flex items-center gap-2">
                    <.icon name="hero-banknotes" class="w-5 h-5" /> Recent Transactions (Last 50)
                  </h3>

                  <div :if={@ledger_entries == []} class="text-center py-12">
                    <.icon name="hero-banknotes" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
                    <p class="text-lg font-medium text-base-content/70">No transactions yet</p>
                  </div>

                  <div :if={@ledger_entries != []} class="overflow-x-auto">
                    <table class="table table-sm table-zebra">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Type</th>
                          <th>Description</th>
                          <th class="text-right">Amount</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={entry <- @ledger_entries}>
                          <td class="text-xs">
                            {Calendar.strftime(entry.created_at, "%m/%d/%y %I:%M %p")}
                          </td>
                          <td>
                            <.icon name={icon_for_meta_1(entry.meta_1)} class="w-4 h-4" />
                          </td>
                          <td class="text-sm">{entry.description}</td>
                          <td class={[
                            "text-right font-mono text-sm",
                            Decimal.positive?(entry.amt) && "text-success",
                            Decimal.negative?(entry.amt) && "text-error"
                          ]}>
                            {QlariusWeb.Money.format_usd(entry.amt)}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
