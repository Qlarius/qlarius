defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Surveys

  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns} title="MeFile Builder">
      <h1>Tag yourself to build up your MeFile.</h1>

      <div class="mt-8 grid gap-6 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
        <%= for category <- @categories do %>
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900">
                {category.name}
              </h3>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.mobile>
    """
  end

  def mount(_params, _session, socket) do
    socket = socket
    |> assign(:categories, Surveys.list_survey_categories())
    {:ok, socket}
  end
end
