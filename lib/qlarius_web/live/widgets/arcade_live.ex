defmodule QlariusWeb.Widgets.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Wallets

  def mount(_params, _session, socket) do
    balance = Wallets.get_user_current_balance(socket.assigns.current_scope.user)
    {:ok, assign(socket, balance: balance)}
  end

  def handle_params(%{"group_id" => group_id} = params, _uri, socket) do
    group = Arcade.get_content_group!(group_id)

    selected_piece =
      with {:ok, content_id} <- Map.fetch(params, "content_id"),
           content_id = String.to_integer(content_id),
           content = %ContentPiece{} <- Enum.find(group.content_pieces, &(&1.id == content_id)) do
        content
      else
        _ ->
          List.first(group.content_pieces)
      end

    socket
    |> assign(group: group, selected_piece: selected_piece)
    |> noreply()
  end

  def handle_event("purchase_tiqit", %{"tiqit-type-id" => tiqit_type_id}, socket) do
    tiqit_type_id = String.to_integer(tiqit_type_id)
    tiqit_type = Enum.find(socket.assigns.selected_piece.tiqit_types, &(&1.id == tiqit_type_id))

    case Arcade.create_tiqit(socket.assigns.current_scope, tiqit_type) do
      {:ok, _tiqit} ->
        {:noreply,
         socket
         |> put_flash(:info, "Purchase successful!")
         |> redirect(to: ~p"/content/#{socket.assigns.selected_piece.id}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to purchase ticket")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row gap-6 p-4">
      <!-- Video Section -->
      <div class="w-full md:w-1/2">
        <div class="aspect-video bg-gray-200 rounded-lg flex items-center justify-center">
          <.icon name="hero-play" class="w-12 h-12 text-gray-500" />
        </div>
        <h2 class="text-xl font-bold mt-4">{@selected_piece.title}</h2>
        <p class="text-sm text-gray-600 mt-2">
          {@selected_piece.description}
        </p>

        <div class="mt-4">
          <%= if Arcade.has_valid_tiqit?(@current_scope, @selected_piece) do %>
            <.link
              navigate={~p"/content/#{@selected_piece.id}"}
              class="inline-block bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600"
            >
              Go to content
            </.link>
          <% else %>
            <%= for tiqit_type <- @selected_piece.tiqit_types do %>
              <div class="flex justify-between items-center bg-white p-1 rounded-lg">
                <span class="text-sm">{tiqit_type.name}</span>
                <button
                  phx-click="purchase_tiqit"
                  phx-value-tiqit-type-id={tiqit_type.id}
                  data-confirm={"Are you sure you want to purchase #{tiqit_type.name} for $#{Decimal.round(tiqit_type.price, 2)}?"}
                  class="bg-gray-300 px-3 py-1 rounded text-sm font-medium hover:bg-gray-400"
                >
                  ${Decimal.round(tiqit_type.price, 2)}
                </button>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="w-full md:w-1/2 space-y-3">
        <%= for piece <- @group.content_pieces do %>
          <.link
            patch={~p"/widgets/arcade/group/#{@group}/?content_id=#{piece.id}"}
            class={"flex flex-col bg-gray-100 p-3 rounded-lg cursor-pointer #{if piece.id == @selected_piece.id, do: "ring-2 ring-black"}"}
          >
            <div class="flex gap-2 mb-1">
              <div class="bg-blue-100 text-blue-800 text-xs font-semibold px-2 py-1 rounded-full">
                {Calendar.strftime(piece.inserted_at, "%d/%m/%y")}
              </div>
              <div class="bg-gray-200 text-gray-700 text-xs font-semibold px-2 py-1 rounded-full">
                {format_duration(piece.length)}
              </div>
              <div class="bg-green-100 text-green-800 text-xs font-semibold px-2 py-1 rounded-full">
                $0.05
              </div>
            </div>
            <div class="font-semibold text-sm">{piece.title}</div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  # TODO I think I can delete Layouts.arcade/1

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, remaining_seconds])
  end
end
