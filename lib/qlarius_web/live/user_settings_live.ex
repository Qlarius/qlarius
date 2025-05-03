defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view
  require Logger

  alias Qlarius.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_user: socket.assigns.current_user)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8">
        <div class="bg-white rounded-lg shadow-sm p-6 sm:p-8">
          <.header class="text-center mb-8">
            <h1 class="text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl">Account Settings</h1>
            <:subtitle class="mt-2 text-sm text-gray-600">Manage your account settings and preferences</:subtitle>
          </.header>

          <div class="space-y-8 divide-y divide-gray-200">
            <%= if @current_user.role == "admin" do %>
              <div class="pt-6">
                <.link
                  navigate={~p"/proxy_users"}
                  class="inline-flex items-center px-4 py-2 rounded-md bg-indigo-50 text-sm font-medium text-indigo-700 hover:bg-indigo-100 transition-colors duration-150 ease-in-out group"
                >
                  Manage Proxy Users
                  <svg class="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform duration-150 ease-in-out" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M3 10a.75.75 0 01.75-.75h10.638L10.23 5.29a.75.75 0 111.04-1.08l5.5 5.25a.75.75 0 010 1.08l-5.5 5.25a.75.75 0 11-1.04-1.08l4.158-3.96H3.75A.75.75 0 013 10z" clip-rule="evenodd" />
                  </svg>
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
