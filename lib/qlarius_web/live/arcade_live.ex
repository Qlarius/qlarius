defmodule QlariusWeb.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade
  alias Qlarius.Arcade.Content
  alias Qlarius.Wallets

  def mount(_params, _session, socket) do
    content = Arcade.list_content()
    balance = Wallets.get_user_current_balance(socket.assigns.current_user)
    {:ok, assign(socket, content: content, balance: balance)}
  end

  def handle_params(params, _uri, socket) do
    selected =
      with {:ok, content_id} <- Map.fetch(params, "content_id"),
           content_id = String.to_integer(content_id),
           content = %Content{} <- Enum.find(socket.assigns.content, &(&1.id == content_id)) do
        content
      else
        _ ->
          List.first(socket.assigns.content)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <div class="flex flex-col md:flex-row gap-6">
        <!-- Video Section -->
        <div class="w-full md:w-1/2">
          <div class="aspect-video bg-gray-200 rounded-lg flex items-center justify-center">
            <.icon name="hero-play" class="w-12 h-12 text-gray-500" />
          </div>
          <h2 class="text-xl font-bold mt-4">{@selected.title}</h2>
          <p class="text-sm text-gray-600 mt-2">
            {@selected.description}
          </p>

          <div class="mt-4">
            <%= for ticket_type <- @selected.ticket_types do %>
              <div class="flex justify-between items-center bg-white p-1 rounded-lg">
                <span class="text-sm">{ticket_type.name}</span>
                <button class="bg-gray-300 px-3 py-1 rounded text-sm font-medium">
                  ${Decimal.round(ticket_type.price, 2)}
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <div class="w-full md:w-1/2 space-y-3">
          <%= for content <- @content do %>
            <.link
              patch={~p"/arcade?content_id=#{content.id}"}
              class={"flex flex-col bg-gray-100 p-3 rounded-lg cursor-pointer #{if content.id == @selected.id, do: "ring-2 ring-black"}"}
            >
              <div class="flex gap-2 mb-1">
                <div class="bg-blue-100 text-blue-800 text-xs font-semibold px-2 py-1 rounded-full">
                  {Calendar.strftime(content.inserted_at, "%d/%m/%y")}
                </div>
                <div class="bg-gray-200 text-gray-700 text-xs font-semibold px-2 py-1 rounded-full">
                  {format_duration(content.length)}
                </div>
                <div class="bg-green-100 text-green-800 text-xs font-semibold px-2 py-1 rounded-full">
                  $0.05
                </div>
              </div>
              <div class="font-semibold text-sm">{content.title}</div>
            </.link>
          <% end %>
        </div>
      </div>

      <div class="mt-6 pt-4 text-center border-t text-gray-800 font-semibold">
        Wallet ${Decimal.round(@balance, 2)}
      </div>
    </div>
    """
  end

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, remaining_seconds])
  end
end
