defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.sponster {assigns}>
      <div class="mx-auto max-w-sm">
        <.header class="text-center">
          Account Settings
          <:subtitle>Manage your account settings</:subtitle>
        </.header>

        <div class="space-y-12 divide-y">
          <div class="pt-6">
            <.button
              navigate={~p"/proxy_users"}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Manage Proxy Users →
            </.button>
          </div>
        </div>
      </div>
    </Layouts.sponster>
    """
  end
end
