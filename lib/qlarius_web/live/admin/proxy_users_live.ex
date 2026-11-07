defmodule QlariusWeb.Admin.ProxyUsersLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Accounts.Users
  alias Qlarius.Sponster.Offers
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Proxy users")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    proxies = Users.list_all_proxies()

    socket
    |> assign(:page_title, "Proxy users")
    |> assign(:proxies, proxies)
    |> assign(
      :counts,
      proxies |> Enum.map(&me_file_id/1) |> Enum.reject(&is_nil/1) |> Offers.offer_counts()
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    proxy = Users.get_proxy!(id)

    socket
    |> assign(:page_title, proxy.proxy_user.alias)
    |> assign_proxy(proxy)
    |> assign(:form, proxy_form(proxy))
  end

  @impl true
  def handle_event("save", %{"proxy" => params}, socket) do
    proxy = socket.assigns.proxy

    case Users.update_proxy_details(proxy, params) do
      {:ok, _result} ->
        {:ok, _} = Offers.refresh_statuses_for_me_file(proxy.proxy_user.me_file.id)
        proxy = Users.get_proxy!(proxy.id)

        {:noreply,
         socket
         |> assign(:page_title, proxy.proxy_user.alias)
         |> assign_proxy(proxy)
         |> assign(:form, proxy_form(proxy))
         |> put_flash(:info, "Proxy saved.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :proxy, errors: changeset.errors))
         |> put_flash(:error, "Check the fields and try again.")}
    end
  end

  def handle_event("reset_offers", _params, socket) do
    proxy = socket.assigns.proxy

    {:ok, %{created: created, current: current}} =
      Offers.reset_for_me_file(proxy.proxy_user.me_file.id)

    {:noreply,
     socket
     |> assign_proxy(proxy)
     |> put_flash(:info, "Offers reset: #{created} offers, #{current} active.")}
  end

  defp assign_proxy(socket, proxy) do
    me_file_id = me_file_id(proxy)
    counts = Map.get(Offers.offer_counts([me_file_id]), me_file_id, %{total: 0, current: 0})

    socket
    |> assign(:proxy, proxy)
    |> assign(:counts, counts)
  end

  defp proxy_form(proxy) do
    me_file = proxy.proxy_user.me_file

    to_form(
      %{
        "alias" => proxy.proxy_user.alias,
        "throttle_ad_count" => me_file.throttle_ad_count,
        "throttle_days" => me_file.throttle_days
      },
      as: :proxy
    )
  end

  defp me_file_id(%{proxy_user: %{me_file: %{id: id}}}), do: id
  defp me_file_id(_proxy), do: nil

  defp counts_for(counts, proxy) do
    Map.get(counts, me_file_id(proxy), %{total: 0, current: 0})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <%= if @live_action == :index do %>
              <.index proxies={@proxies} counts={@counts} />
            <% else %>
              <.editor proxy={@proxy} form={@form} counts={@counts} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp index(assigns) do
    ~H"""
    <.page class="max-w-6xl">
      <.page_header
        title="Proxy users"
        count={length(@proxies)}
        subtitle="Personas admins use to test ads, with their PTP throttle."
      />

      <.panel flush>
        <.empty_state :if={@proxies == []} icon="hero-user-group" title="No proxy users yet" />

        <.data_table
          :if={@proxies != []}
          id="proxy-users-table"
          rows={@proxies}
          row_click={fn proxy -> JS.navigate(~p"/admin/proxy_users/#{proxy.id}") end}
        >
          <:col :let={proxy} label="Proxy">
            <.link navigate={~p"/admin/proxy_users/#{proxy.id}"} class="font-semibold hover:underline">
              {proxy.proxy_user.alias}
            </.link>
          </:col>
          <:col :let={proxy} label="True user">{proxy.true_user && proxy.true_user.alias}</:col>
          <:col :let={proxy} label="Active">
            <span :if={proxy.active} class="badge badge-sm badge-success">Active</span>
          </:col>
          <:col :let={proxy} label="Throttle">
            <%= if me_file = proxy.proxy_user.me_file do %>
              {me_file.throttle_ad_count} per {me_file.throttle_days} days
            <% end %>
          </:col>
          <:col :let={proxy} label="Offers">
            {counts_for(@counts, proxy).current} active of {counts_for(@counts, proxy).total}
          </:col>
        </.data_table>
      </.panel>
    </.page>
    """
  end

  defp editor(assigns) do
    ~H"""
    <.page class="max-w-3xl">
      <.page_header
        title={@proxy.proxy_user.alias}
        subtitle={"Proxy of #{@proxy.true_user && @proxy.true_user.alias}"}
        back_to={~p"/admin/proxy_users"}
        back_label="Proxy users"
      >
        <:actions>
          <.link
            :if={@proxy.proxy_user.me_file}
            navigate={~p"/admin/mefile_inspector/#{@proxy.proxy_user.me_file.id}"}
            class="btn btn-sm btn-ghost"
          >
            <.icon name="hero-magnifying-glass" class="size-4" /> MeFile Inspector
          </.link>
        </:actions>
      </.page_header>

      <div class="space-y-6">
        <.form for={@form} phx-submit="save" id="proxy-form">
          <.panel title="Proxy">
            <.input field={@form[:alias]} label="Alias" />
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@form[:throttle_ad_count]}
                type="number"
                label="Throttled ads"
                min="0"
                max="1000"
              />
              <.input
                field={@form[:throttle_days]}
                type="number"
                label="Days"
                min="0"
                max="365"
              />
            </div>
            <p class="text-sm text-base-content/60">
              Days of 0 caps only the ads active at once.
            </p>
            <:footer>
              <button type="submit" class="btn btn-primary btn-sm">Save proxy</button>
            </:footer>
          </.panel>
        </.form>

        <.panel
          title="Offers"
          description="Reset deletes this proxy's offers and rebuilds them from its targets. Completed ads stay completed."
        >
          <dl class="grid gap-4 sm:grid-cols-2">
            <.detail_item label="All offers" value={@counts.total} />
            <.detail_item label="Active offers" value={@counts.current} />
          </dl>
          <:footer>
            <button
              type="button"
              id="reset-offers"
              phx-click="reset_offers"
              data-confirm="Delete and rebuild every offer for this proxy?"
              class="btn btn-sm btn-ghost text-error"
            >
              <.icon name="hero-arrow-path" class="size-4" /> Reset offers
            </button>
          </:footer>
        </.panel>
      </div>
    </.page>
    """
  end
end
