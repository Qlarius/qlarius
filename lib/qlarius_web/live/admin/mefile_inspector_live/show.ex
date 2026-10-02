defmodule QlariusWeb.Admin.MeFileInspectorLive.Show do
  use QlariusWeb, :live_view
  import Ecto.Query
  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Repo
  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  alias Qlarius.Wallets
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
  def handle_event("update_credit_allowance", %{"credit_allowance" => value}, socket) do
    case Wallets.update_credit_allowance(socket.assigns.me_file, value) do
      {:ok, updated} ->
        me_file = %{socket.assigns.me_file | credit_allowance: updated.credit_allowance}

        {:noreply,
         socket
         |> assign(:me_file, me_file)
         |> assign_user_details()
         |> put_flash(:info, "Credit allowance updated")}

      {:error, :below_minimum} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Cannot lower allowance below the amount already used against the activity ledger"
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update credit allowance")}
    end
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
          {:noreply, put_flash(socket, :warning, "⚠️ User has no active push subscriptions")}

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
    summary = Wallets.consumer_wallet_summary(me_file)

    socket
    |> assign(:user, user)
    |> assign(:masked_mobile, masked_mobile)
    |> assign(:home_zip, home_zip)
    |> assign(:wallet_balance, wallet_balance)
    |> assign(:wallet_summary, summary)
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

    socket
    |> assign(:tag_map, tag_map)
    |> assign(:tag_count, MeFile.trait_tag_count(socket.assigns.me_file))
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
  defp icon_for_meta_1("Friend gift credit"), do: "hero-gift"
  defp icon_for_meta_1("Media gift credit"), do: "hero-gift"
  defp icon_for_meta_1("Tip/Donation"), do: "hero-gift"
  defp icon_for_meta_1("Tiqit Purchase"), do: "hero-ticket"
  defp icon_for_meta_1("Referral Bonus"), do: "hero-user-group"
  defp icon_for_meta_1("Text/Jump"), do: "hero-arrow-right-start-on-rectangle"
  defp icon_for_meta_1("Banner Tap"), do: "hero-photo"
  defp icon_for_meta_1("Video Ad"), do: "hero-film"
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
            <.page class="max-w-5xl">
              <.page_header
                title={@user.alias}
                subtitle={"MeFile ##{@me_file.id}"}
                back_to={~p"/admin/mefile_inspector"}
                back_label="MeFile Inspector"
              >
                <:badges>
                  <.chip :if={@home_zip} class="gap-1">
                    <.icon name="hero-map-pin" class="size-3.5" /> {@home_zip}
                  </.chip>
                </:badges>
                <:actions>
                  <button
                    type="button"
                    phx-click="send_test_notification"
                    data-confirm="Send a test ad count notification to this user right now?"
                    class="btn btn-sm btn-ghost"
                    title="Send test ad count notification"
                  >
                    <.icon name="hero-bell-alert" class="size-4" /> Send test notification
                  </button>
                  <div class="join">
                    <button
                      type="button"
                      phx-click="navigate_prev"
                      disabled={is_nil(@prev_user_id)}
                      class="join-item btn btn-sm"
                    >
                      <.icon name="hero-chevron-left" class="size-4" /> Previous
                    </button>
                    <button
                      type="button"
                      phx-click="navigate_next"
                      disabled={is_nil(@next_user_id)}
                      class="join-item btn btn-sm"
                    >
                      Next <.icon name="hero-chevron-right" class="size-4" />
                    </button>
                  </div>
                </:actions>
              </.page_header>

              <div class="mb-8 grid grid-cols-2 gap-3 lg:grid-cols-4">
                <.stat_tile label="Available to spend" icon="hero-wallet">
                  {QlariusWeb.Money.format_usd(@wallet_summary.available_to_spend)}
                </.stat_tile>
                <.stat_tile label="Activity" icon="hero-banknotes">
                  {QlariusWeb.Money.format_usd(@wallet_balance)}
                </.stat_tile>
                <.stat_tile label="Tags" icon="hero-tag">{@tag_count}</.stat_tile>
                <.stat_tile label="Active offers" icon="hero-megaphone">
                  {length(@offers)}
                </.stat_tile>
              </div>

              <div class="mb-8 grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_320px]">
                <.panel title="Details">
                  <dl class="grid gap-x-6 gap-y-4 sm:grid-cols-2">
                    <.detail_item label="Alias" value={@user.alias} />
                    <.detail_item label="Mobile" value={@masked_mobile} />
                    <.detail_item label="Home zip" value={@home_zip} />
                    <.detail_item
                      label="Registered"
                      value={Calendar.strftime(@registered_at, "%m/%d/%Y %I:%M %p")}
                    />
                    <.detail_item
                      label="Last sign-in"
                      value={
                        @last_sign_in_at &&
                          Calendar.strftime(@last_sign_in_at, "%m/%d/%Y %I:%M %p")
                      }
                    />
                  </dl>
                </.panel>

                <form phx-submit="update_credit_allowance">
                  <.panel
                    title="Credit allowance"
                    description="Cannot be lowered below the amount already used."
                  >
                    <label class="block">
                      <span class="mb-1 block text-xs text-base-content/60">Allowance</span>
                      <input
                        type="text"
                        name="credit_allowance"
                        value={@me_file.credit_allowance}
                        class="input w-full"
                      />
                    </label>
                    <:footer>
                      <button type="submit" class="btn btn-sm btn-primary">Update allowance</button>
                    </:footer>
                  </.panel>
                </form>
              </div>

              <div class="mb-8 grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_320px]">
                <.panel title="Tags">
                  <:actions>
                    <span class="rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium text-base-content/70">
                      {@tag_count}
                    </span>
                  </:actions>
                  <.empty_state :if={@tag_map == []} icon="hero-tag" title="No tags yet" />

                  <div :if={@tag_map != []} class="divide-y divide-base-300">
                    <section
                      :for={{{_id, name, _display_order}, parent_traits} <- @tag_map}
                      class="py-5 first:pt-0 last:pb-0"
                    >
                      <div class="mb-3 flex items-baseline justify-between gap-3">
                        <h3 class="text-sm font-semibold">{name}</h3>
                        <span class="text-xs text-base-content/50">
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
                    </section>
                  </div>
                </.panel>

                <.panel title="Active offers">
                  <:actions>
                    <span class="rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium text-base-content/70">
                      {length(@offers)}
                    </span>
                  </:actions>
                  <.empty_state :if={@offers == []} icon="hero-megaphone" title="No active offers" />

                  <div :for={offer <- @offers} class="space-y-1">
                    <QlariusWeb.Components.AdsComponents.three_tap_ad
                      media_piece={offer.media_piece}
                      show_banner={true}
                    />
                    <div class="flex justify-between gap-2 text-xs text-base-content/60">
                      <span>Offer {QlariusWeb.Money.format_usd(offer.offer_amt)}</span>
                      <span class="text-base-content/50">Campaign #{offer.campaign_id}</span>
                    </div>
                  </div>
                </.panel>
              </div>

              <.panel flush title="Recent transactions" description="Last 50 ledger entries.">
                <.empty_state
                  :if={@ledger_entries == []}
                  icon="hero-banknotes"
                  title="No transactions yet"
                />

                <.data_table
                  :if={@ledger_entries != []}
                  id="mefile-ledger-entries"
                  rows={@ledger_entries}
                  row_id={&"mefile-ledger-entry-#{&1.id}"}
                >
                  <:col
                    :let={entry}
                    label="Date"
                    class="whitespace-nowrap text-xs text-base-content/60"
                  >
                    {Calendar.strftime(entry.created_at, "%m/%d/%y %I:%M %p")}
                  </:col>
                  <:col :let={entry} label="Type">
                    <span title={entry.meta_1} class="text-base-content/60">
                      <.icon name={icon_for_meta_1(entry.meta_1)} class="size-4" />
                    </span>
                  </:col>
                  <:col :let={entry} label="Description">{entry.description}</:col>
                  <:col :let={entry} label="Amount" class="text-right whitespace-nowrap">
                    <span class={[
                      Decimal.positive?(entry.amt) && "text-success",
                      Decimal.negative?(entry.amt) && "text-error"
                    ]}>
                      {QlariusWeb.Money.format_usd(entry.amt)}
                    </span>
                  </:col>
                </.data_table>
              </.panel>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
