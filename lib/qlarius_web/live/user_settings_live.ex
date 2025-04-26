defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view
  require Logger

  alias Qlarius.Accounts
  alias Qlarius.DatabaseConfig

  def mount(_params, _session, socket) do
    if connected?(socket) do
      current_mode = DatabaseConfig.get_current_mode()
      Logger.debug("Initial mode on mount: #{inspect(current_mode)}")
      {:ok, assign(socket, current_user: socket.assigns.current_user, db_mode: current_mode, error_message: nil)}
    else
      {:ok, assign(socket, current_user: socket.assigns.current_user, db_mode: :local, error_message: nil)}
    end
  end

  def handle_event("toggle_db_mode", _params, socket) do
    try do
      new_mode = DatabaseConfig.toggle_mode()
      {:noreply, assign(socket, db_mode: new_mode, error_message: nil)}
    rescue
      e ->
        Logger.error("Error toggling database mode: #{inspect(e)}")
        {:noreply, assign(socket, :error_message, "Failed to switch database mode. Please try again.")}
    end
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

              <div class="pt-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Database Configuration</h3>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-700">
                    Current Mode: <span class="font-medium"><%= String.capitalize(to_string(@db_mode)) %></span>
                  </span>
                  <button
                    phx-click="toggle_db_mode"
                    class={"px-4 py-2 rounded-md text-sm font-medium transition-colors duration-150 ease-in-out #{if @db_mode == :local, do: "bg-blue-50 text-blue-700 hover:bg-blue-100", else: "bg-green-50 text-green-700 hover:bg-green-100"}"}
                  >
                    Switch to <%= if @db_mode == :local, do: "Remote", else: "Local" %>
                  </button>
                </div>
                <%= if @error_message do %>
                  <p class="mt-2 text-sm text-red-600"><%= @error_message %></p>
                <% end %>
                <p class="mt-2 text-sm text-gray-500">
                  <%= if @db_mode == :local do %>
                    Using local development database
                  <% else %>
                    Connected to remote database
                  <% end %>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
