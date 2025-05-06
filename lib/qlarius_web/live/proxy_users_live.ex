defmodule QlariusWeb.ProxyUsersLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Scope
  alias Qlarius.Accounts.User
  alias Qlarius.Accounts.UserProxy
  alias Qlarius.Accounts.Proxying

  on_mount {QlariusWeb.UserAuth, :require_admin_or_proxy}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    true_user = scope.true_user
    proxy_users = Proxying.list_proxy_users(true_user)

    socket
    |> assign(:true_user, true_user)
    |> assign(:proxy_users, proxy_users)
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <div class="mx-auto max-w-2xl">
        <.header>
          Proxy Users
          <:subtitle>Manage and switch between proxy users</:subtitle>
        </.header>

        <div class="my-5">
          <.button
            :if={Enum.any?(@proxy_users, & &1.active)}
            phx-click="cancel_proxy"
            variant="primary"
          >
            Stop proxying
          </.button>
        </div>

        <.table id="proxy_users" rows={@proxy_users}>
          <:col :let={proxy} label="Username">{proxy.proxy_user.username}</:col>
          <:col :let={proxy} label="Email">{proxy.proxy_user.email}</:col>
          <:col :let={proxy} label="Status">
            <.button
              phx-click="toggle_proxy"
              phx-value-id={proxy.id}
              variant={if proxy.active, do: "primary"}
            >
              {if proxy.active, do: "Active", else: "Inactive"}
            </.button>
          </:col>
        </.table>
      </div>
    </Layouts.sponster>
    """
  end

  def handle_event("cancel_proxy", _params, socket) do
    true_user = socket.assigns.true_user
    :ok = Proxying.cancel_active_proxy(true_user)

    socket
    |> assign(:proxy_users, Proxying.list_proxy_users(true_user))
    |> assign(:current_scope, Scope.for_user(true_user))
    |> put_flash(:info, "Cancelled proxy. Switched back to #{true_user.username}")
    |> noreply()
  end

  def handle_event("toggle_proxy", %{"id" => proxy_id}, socket) do
    true_user = socket.assigns.true_user

    {:ok, updated_proxy} = Proxying.set_active_user_proxy(true_user, proxy_id)

    proxy_user = updated_proxy.proxy_user

    # Update socket assigns with new proxy user and scope, but keep admin user for the proxy list
    socket
    |> assign(:proxy_users, Proxying.list_proxy_users(true_user))
    |> assign(:current_scope, Scope.for_user(true_user))
    |> put_flash(:info, "Successfully switched to proxy user #{proxy_user.username}")
    |> noreply()
  end
end
