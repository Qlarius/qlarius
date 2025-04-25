defmodule QlariusWeb.Widgets.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.TiqitType

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(
      balance: scope && scope.wallet_balance,
      selected_tiqit_type: nil
    )
    |> ok()
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
          <%= if @current_scope && Arcade.has_valid_tiqit?(@current_scope, @selected_piece) do %>
            <%!-- TODO remove hardcoded user --%>
            <.link
              navigate={~p"/widgets/content/#{@selected_piece.id}?user=#{@current_scope.user.email}"}
              class="inline-block bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600"
            >
              Go to content
            </.link>
          <% else %>
            <div
              :for={tiqit_type <- @selected_piece.tiqit_types}
              class="flex justify-between items-center bg-white p-1 rounded-lg"
            >
              <span class="text-sm">{tiqit_type.name}</span>
              <button
                phx-click="select-tiqit-type"
                phx-value-tiqit-type-id={tiqit_type.id}
                class="bg-gray-300 px-3 py-1 rounded text-sm font-medium hover:bg-gray-400"
              >
                ${Decimal.round(tiqit_type.price, 2)}
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <div class="w-full md:w-1/2 space-y-3">
        <.link
          :for={piece <- @group.content_pieces}
          patch={
            ~p"/widgets/arcade/group/#{@group}/?content_id=#{piece.id}&user=#{@current_scope.user.email}"
          }
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
      </div>
    </div>

    <.modal
      :if={@selected_tiqit_type}
      id="confirm-purchase-modal"
      on_cancel={JS.push("close-confirm-purchase-modal")}
      show
    >
      <div class="relative">
        <div class="bg-black h-40 flex items-center justify-center">
          <.icon name="hero-play-solid" class="w-12 h-12 text-white" />
        </div>
      </div>
      <h2 class="mt-4 text-xl font-bold text-gray-800">
        {@selected_piece.title}
      </h2>
      <p class="mt-2 text-gray-600">
        {tiqit_type_duration(@selected_tiqit_type)}
      </p>
      <div class="mt-4 flex items-center justify-between bg-gray-100 p-3 rounded-md">
        <div class="flex items-center">
          <.icon class="w-5 h-5 text-green-500 mr-2" name="hero-check-circle-solid" />
          <span class="text-gray-700">Balance: ${Decimal.round(@balance, 2)}</span>
        </div>
        <button
          class="bg-orange-500 text-white px-4 py-2 rounded-md hover:bg-orange-600 focus:ring-2 focus:ring-orange-800 focus:outline-none"
          phx-click="purchase-tiqit"
          phx-value-tiqit-type-id={@selected_tiqit_type.id}
        >
          Confirm purchase (${Decimal.round(@selected_tiqit_type.price, 2)})
        </button>
      </div>
      <div class="mt-4 flex items-center justify-between">
        <div class="flex items-center">
          <.icon name="hero-ticket" class="w-5 h-5 text-orange-500 mr-1" />
          <span class="text-orange-500 font-semibold">TIQIT</span>
        </div>
      </div>
    </.modal>
    """
  end

  # TODO I think I can delete Layouts.arcade/1

  defp tiqit_type_duration(%TiqitType{} = tt) do
    # Returns duration as:
    # - "X weeks" if evenly divisible by 7 days (168 hours)
    # - "X days" if evenly divisible by 24 hours (exception: "24 hours" not "1 day")
    # - "X hours" otherwise
    # Examples: "2 weeks", "3 days", "26 hours"
    if tt.duration_hours do
      duration =
        cond do
          rem(tt.duration_hours, 24 * 7) == 0 ->
            "#{div(tt.duration_hours, 24 * 7)} week#{if div(tt.duration_hours, 24 * 7) > 1, do: "s"}"

          rem(tt.duration_hours, 24) == 0 and tt.duration_hours != 24 ->
            "#{div(tt.duration_hours, 24)} day#{if div(tt.duration_hours, 24) > 1, do: "s"}"

          true ->
            "#{tt.duration_hours} hour#{if tt.duration_hours > 1, do: "s"}"
        end

      "You are purchasing access for #{duration}"
    else
      "You are purchasing lifetime access"
    end
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    socket |> assign(selected_tiqit_type: nil) |> noreply()
  end

  def handle_event("select-tiqit-type", %{"tiqit-type-id" => tt_id}, socket) do
    id = String.to_integer(tt_id)
    tt = %TiqitType{} = Enum.find(socket.assigns.selected_piece.tiqit_types, &(&1.id == id))
    socket |> assign(selected_tiqit_type: tt) |> noreply()
  end

  def handle_event("purchase-tiqit", %{"tiqit-type-id" => tiqit_type_id}, socket) do
    tiqit_type_id = String.to_integer(tiqit_type_id)
    tiqit_type = Enum.find(socket.assigns.selected_piece.tiqit_types, &(&1.id == tiqit_type_id))

    :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_type)

    user = socket.assigns.current_scope.user

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    socket
    |> redirect(
      to:
        ~p"/widgets/content/#{socket.assigns.selected_piece.id}?user=#{socket.assigns.current_scope.user.email}"
    )
    |> noreply()
  end
end
