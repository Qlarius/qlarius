defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_user, socket.assigns.current_user)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Account Settings
        <:subtitle>Manage your account settings</:subtitle>
      </.header>

      <div class="space-y-12 divide-y">
        <%= if @current_user.role == "admin" do %>
          <div class="pt-6">
            <.link
              navigate={~p"/proxy_users"}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Manage Proxy Users →
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
