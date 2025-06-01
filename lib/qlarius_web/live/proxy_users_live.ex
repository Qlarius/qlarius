defmodule QlariusWeb.ProxyUsersLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Accounts.UserProxy
  alias Qlarius.Accounts.Scope
  alias QlariusWeb.Layouts

  @debug false

  import Layouts,
    only: [
      toggle_sponster_sidebar: 1,
      sponster_sidebar: 1,
      sponster_bottom_bar_link: 1
    ]

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope.true_user.role == "admin" do
      admin_user = socket.assigns.current_scope.true_user
      proxy_users = list_proxy_users(admin_user)
      active_proxy = get_active_proxy(admin_user)

      {:ok,
       socket
       # Store the admin user
       |> assign(:original_user, admin_user)
       |> assign(:proxy_users, proxy_users)
       |> assign(:active_proxy, active_proxy)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <div class="mx-auto max-w-2xl">
        <.header>
          Proxy Users
          <:subtitle>Manage and switch between proxy users</:subtitle>
        </.header>

        <.table id="proxy_users" rows={@proxy_users}>
          <:col :let={proxy} label="Username">{proxy.proxy_user.username}</:col>
          <:col :let={proxy} label="Alias">{proxy.proxy_user.email}</:col>
          <:col :let={proxy} label="Status">
            <.button
              phx-click="toggle_proxy"
              phx-value-id={proxy.id}
              class={
                "transition-colors " <>
                if proxy.active do
                  "!bg-green-500 hover:!bg-green-600"
                else
                  "!bg-gray-500 hover:!bg-gray-600"
                end
              }
            >
              {if proxy.active, do: "Active", else: "Inactive"}
            </.button>
          </:col>
        </.table>
      </div>
      <!-- Debug section -->
      <pre class="mt-8 p-4 bg-gray-100 rounded overflow-auto text-sm">
        <%= inspect(assigns, pretty: true) %>
      </pre>
    </Layouts.sponster>
    """
  end

  def handle_event("toggle_dark_mode", _params, socket) do
    # For now, we'll just acknowledge the event without implementing dark mode
    {:noreply, socket}
  end

  def handle_event("toggle_proxy", %{"id" => proxy_id}, socket) do
    proxy_id = String.to_integer(proxy_id)
    admin_user = socket.assigns.current_scope.true_user

    # Deactivate current proxy if exists
    if socket.assigns.active_proxy do
      {:ok, _} = Users.update_user_proxy(socket.assigns.active_proxy, %{active: false})
    end

    # Activate new proxy
    proxy = Enum.find(socket.assigns.proxy_users, &(&1.id == proxy_id))
    {:ok, updated_proxy} = Users.update_user_proxy(proxy, %{active: true})

    # Refresh proxy users list using the admin user
    proxy_users = list_proxy_users(admin_user)

    # Update socket assigns with new proxy user and scope, but keep admin user for the proxy list
    {:noreply,
     socket
     |> assign(:proxy_users, proxy_users)
     |> assign(:active_proxy, updated_proxy)
     |> assign(:true_user, admin_user)
     |> assign(:current_scope, Scope.for_user(admin_user))
     |> put_flash(
       :info,
       "Successfully switched to proxy user #{updated_proxy.proxy_user.username}"
     )}
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
