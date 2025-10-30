defmodule QlariusWeb.Live.Marketers.CampaignsManagerLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Campaigns")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <.current_marketer_bar
        current_marketer={@current_marketer}
        current_path={~p"/marketer/campaigns"}
      />
      <div class="p-6">
        <h1 class="text-2xl font-bold mb-4">Campaign Manager</h1>
        <p class="text-base-content/70">Campaign management interface coming soon.</p>
      </div>
    </Layouts.admin>
    """
  end
end
