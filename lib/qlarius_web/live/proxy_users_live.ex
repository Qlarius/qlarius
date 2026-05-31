defmodule QlariusWeb.ProxyUsersLive do
  use QlariusWeb, :live_view

  alias Phoenix.LiveView.JS
  alias Qlarius.Accounts.Users

  # Commented out unused alias - UserProxy not directly referenced (all proxy operations use Users module functions)
  # alias Qlarius.Accounts.UserProxy
  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Layouts
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  # Commented out unused import - Layouts functions not used in this LiveView
  # import Layouts,
  #   only: [
  #     toggle_sponster_sidebar: 1,
  #     sponster_sidebar: 1,
  #     sponster_bottom_bar_link: 1
  #   ]

  def mount(_params, session, socket) do
    if socket.assigns.current_scope.true_user.role == "admin" do
      admin_user = socket.assigns.current_scope.true_user
      proxy_users = list_proxy_users(admin_user)
      active_proxy = get_active_proxy(admin_user)

      {:ok,
       socket
       |> assign(:original_user, admin_user)
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, active_proxy)
       |> assign(:title, "Proxy Users")
       |> assign(:current_path, "/proxy_users")
       |> assign(:show_add_modal, false)
       |> init_pwa_assigns(session)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_dark_mode", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("navigate_to_settings", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/settings")}
  end

  # B4: Open the in-place ProxyUserSheet instead of push_navigating to
  # `/register?mode=proxy`. The legacy route stays alive as a fallback.
  def handle_event("add_proxy", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, true)}
  end

  def handle_event("close_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  def handle_event("toggle_proxy", %{"id" => proxy_id}, socket) do
    proxy_id = String.to_integer(proxy_id)
    admin_user = socket.assigns.current_scope.true_user
    proxy = Enum.find(socket.assigns.proxy_users, &(&1.id == proxy_id))

    if proxy.active do
      {:ok, _} = Users.update_user_proxy(proxy, %{active: false})
      proxy_users = list_proxy_users(admin_user)

      {:noreply,
       socket
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, nil)
       |> assign(:current_scope, Scope.for_user(admin_user))
       |> put_flash(:info, "Returned to admin user")}
    else
      if socket.assigns.active_proxy do
        {:ok, _} = Users.update_user_proxy(socket.assigns.active_proxy, %{active: false})
      end

      {:ok, updated_proxy} = Users.update_user_proxy(proxy, %{active: true})
      proxy_users = list_proxy_users(admin_user)

      {:noreply,
       socket
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, updated_proxy)
       |> assign(:current_scope, Scope.for_user(admin_user))
       |> put_flash(
         :info,
         "Successfully switched to proxy user #{updated_proxy.proxy_user.alias}"
       )}
    end
  end

  # Raised by ProxyUserSheet via `send(self(), ...)` on successful
  # creation. Refresh the list; leave the modal open so the sheet can
  # offer its "Add another" affordance. Admin dismisses it explicitly.
  def handle_info({:proxy_user_created, user}, socket) do
    admin_user = socket.assigns.current_scope.true_user
    proxy_users = list_proxy_users(admin_user)

    {:noreply,
     socket
     |> assign(:proxy_users, proxy_users)
     |> put_flash(:info, "Proxy user #{user.alias} created")}
  end

  def render(assigns) do
    ~H"""
    <div id="proxyusers-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="mx-auto max-w-2xl">
          <button
            phx-click="navigate_to_settings"
            class="btn btn-outline rounded-full text-lg mb-4 !border-base-content/30 !px-3 !py-1"
          >
            <.icon name="hero-chevron-left" class="w-5 h-5" /> Back
          </button>

          <div class="flex justify-between items-center mb-4">
            <p class="mobile-page-intro">Deselect all to return to true user.</p>
            <button class="btn btn-primary btn-lg rounded-full gap-2 px-5" phx-click="add_proxy">
              <.icon name="hero-plus" class="w-5 h-5" /> Add Proxy User
            </button>
          </div>

          <.surface_panel padding={false}>
            <ul class="list !mx-0 !rounded-none !shadow-none !bg-base-100 dark:!bg-black divide-y divide-base-300/60 dark:divide-base-content/10">
            <li
              :for={proxy <- @proxy_users}
              class={[
                "list-row cursor-pointer transition-all duration-200 !rounded-none hover:bg-base-200/70 dark:hover:bg-base-300/35",
                proxy.active &&
                  "!bg-green-50 dark:!bg-green-900/30 border-l-4 border-green-500 dark:border-green-400 pl-4"
              ]}
              phx-click="toggle_proxy"
              phx-value-id={proxy.id}
            >
              <div class="list-col-grow">
                <div class="text-lg font-medium text-base-content">{proxy.proxy_user.alias}</div>
              </div>
              <div class="flex items-center mr-2">
                <%= if proxy.active do %>
                  <.icon name="hero-check-circle-solid" class="h-8 w-8 text-green-500" />
                <% else %>
                  <div class="h-8 w-8 rounded-full border-2 border-base-content/30"></div>
                <% end %>
              </div>
            </li>
            </ul>
          </.surface_panel>
        </div>
      </Layouts.mobile>

      <.live_component
        module={QlariusWeb.Components.ProxyUserSheet}
        id="proxy-user-sheet"
        show={@show_add_modal}
        admin={@current_scope.true_user}
        on_cancel={JS.push("close_add_modal")}
      />
    </div>
    """
  end

  # Private functions

  defp list_proxy_users(user) do
    user
    |> Users.list_proxy_users()
    |> Users.preload_proxy_users()
  end

  defp get_active_proxy(user) do
    user
    |> Users.get_active_proxy_user()
  end
end
