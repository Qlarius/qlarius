defmodule QlariusWeb.Widgets.ArcadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets

  import QlariusWeb.Money
  import QlariusWeb.TiqitClassHTML

  def mount(%{"group_id" => group_id}, _session, socket) do
    # Prevent double mounting - only initialize if not already mounted
    if connected?(socket) and socket.assigns[:mounted] do
      # Already mounted, just update balance and return
      scope = socket.assigns.current_scope

      {:ok,
       socket
       |> assign(
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount
       )}
    else
      # First mount - do full initialization
      scope = socket.assigns.current_scope

      # Load data once
      group = Arcade.get_content_group!(group_id)

      pieces =
        group.content_pieces
        |> Enum.filter(&Enum.any?(&1.tiqit_classes))
        # Sort by ID to ensure consistent order; change to proper display order later
        |> Enum.sort_by(& &1.id)

      # Generate random durations only once per piece (cache them)
      pieces =
        Enum.map(pieces, fn piece ->
          # Use piece ID as seed for consistent but random durations
          :rand.seed(:exsplus, {piece.id, piece.id, piece.id})
          # 19..32 range
          hours = :rand.uniform(14) + 18
          # 1..59 range
          minutes = :rand.uniform(59) + 1
          duration = :io_lib.format("~2..0B min ~2..0B sec", [hours, minutes])
          Map.put(piece, :duration, duration)
        end)

      # Subscribe to wallet updates only once
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{scope.user.id}")

      {:ok,
       socket
       |> assign(
         mounted: true,
         balance: scope && scope.wallet_balance,
         offered_amount: scope && scope.offered_amount,
         group: group,
         pieces: pieces,
         selected_tiqit_class: nil
       )}
    end
  end

  def handle_params(params, _uri, socket) do
    pieces = socket.assigns.pieces

    selected_piece =
      with {:ok, content_id} <- Map.fetch(params, "content_id"),
           content_id = String.to_integer(content_id),
           content = %ContentPiece{} <- Enum.find(pieces, &(&1.id == content_id)) do
        content
      else
        _ ->
          List.first(pieces)
      end

    default_tiqit_class =
      if selected_piece do
        ContentPiece.default_tiqit_class(selected_piece)
      else
        nil
      end

    tiqit =
      if selected_piece do
        Arcade.get_valid_tiqit(socket.assigns.current_scope, selected_piece)
      else
        nil
      end

    socket
    |> assign(selected_piece: selected_piece)
    |> assign(default_tiqit_class: default_tiqit_class)
    |> assign(tiqit: tiqit)
    |> noreply()
  end

  attr :balance, Decimal, required: true
  attr :piece, ContentPiece, required: true
  attr :group, ContentGroup, required: true

  defp tiqit_class_grid(assigns) do
    piece = assigns.piece
    group = assigns.group
    catalog = group.catalog

    durations =
      [piece, group, catalog]
      |> Enum.flat_map(&for tc <- &1.tiqit_classes, do: tc.duration_hours)
      |> Enum.uniq()
      |> Enum.sort()

    assigns =
      assign(assigns,
        catalog: catalog,
        durations: durations,
        group: group,
        piece: piece,
        show_group?: Enum.any?(group.tiqit_classes),
        show_catalog?: Enum.any?(catalog.tiqit_classes)
      )

    ~H"""
    <div class="flex justify-center">
      <div class="overflow-x-auto w-full max-w-4xl">
        <table class="table table-compact !w-auto inline-table mx-auto table-fixed">
          <colgroup>
            <col class="w-40" />
            <col class="w-40" />
            <col :if={@show_group?} class="w-40" />
            <col :if={@show_catalog?} class="w-40" />
          </colgroup>
          <thead class="bg-base-200">
            <tr>
              <th class="w-40 font-semibold text-base-content text-right py-2 px-3 whitespace-nowrap">
                Duration
              </th>
              <th class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none">
                Single<br />{@catalog.piece_type |> to_string() |> String.capitalize()}
              </th>
              <th
                :if={@show_group?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                Entire {@catalog.group_type |> to_string() |> String.capitalize()}<br />
                <span class="text-base-content/40 text-xs mt-0">
                  ({length(@group.content_pieces)} episodes)
                </span>
              </th>
              <th
                :if={@show_catalog?}
                class="w-40 font-semibold text-base-content text-center py-2 px-3 leading-none"
              >
                <%!-- Entire {@catalog.type |> to_string() |> String.capitalize()}<br /><span class="text-base-content/40 text-xs mt-0"> --%>
                Entire Site<br />
                <span class="text-base-content/40 text-xs mt-0">
                  (9 series)
                </span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-base-300">
            <tr :for={duration <- @durations}>
              <td class="font-bold text-base-content text-right p-3 whitespace-nowrap">
                {format_tiqit_class_duration(duration)}
                <.icon name="hero-arrow-right" class="w-4 h-4 ml-1 text-base-content/60" />
              </td>
              <%= for {col, true} <- [{@piece, true}, {@group, @show_group?}, {@catalog, @show_catalog?}] do %>
                <td class="w-40 text-center py-1 px-3">
                  <%= if class = Enum.find(col.tiqit_classes, & &1.duration_hours == duration) do %>
                    <div class="flex justify-center">
                      <.tiqit_class_grid_price balance={@balance} tiqit_class={class} />
                    </div>
                  <% else %>
                    <span class="text-base-content/40 text-sm">-</span>
                  <% end %>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :tiqit_class, TiqitClass, required: true
  attr :balance, Decimal, required: true

  defp tiqit_class_grid_price(assigns) do
    ~H"""
    <%= if Decimal.compare(@balance, @tiqit_class.price) != :lt do %>
      <button
        phx-click="select-tiqit-class"
        phx-value-tiqit-class-id={@tiqit_class.id}
        class="btn btn-sm rounded-full btn-primary px-3 py-1 cursor-pointer"
      >
        {format_usd(@tiqit_class.price)}
      </button>
    <% else %>
      <div class="btn btn-xs btn-primary px-3 py-1 rounded disabled line-through">
        {format_usd(@tiqit_class.price)}
      </div>
    <% end %>
    """
  end

  attr :balance, Decimal, required: true
  attr :offered_amount, Decimal, required: true

  defp wallet_strip(assigns) do
    ~H"""
    <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-3 py-2 rounded-lg border-1 border-base-300">
      <div class="flex flex-row flex-wrap justify-between items-center space-x-4">
        <span class="font-bold text-lg text-sponster-600 dark:text-sponster-300">
          {format_usd(@balance)}
          <span class="font-normal text-base-content/60 ml-1 mr-3">to spend</span>
        </span>

        <button
          class="btn btn-md rounded-full !bg-sponster-400 hover:!bg-sponster-600 text-white !border-sponster-400 hover:!border-sponster-600 leading-none"
          phx-click="show-topup-modal"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-0" /> Top up •
          <span class="font-bold">{format_usd(@offered_amount)}</span>
        </button>
      </div>
    </div>
    """
  end

  def handle_event("close-confirm-purchase-modal", _params, socket) do
    socket |> assign(selected_tiqit_class: nil) |> noreply()
  end

  def handle_event("close-topup-modal", _params, socket) do
    socket |> assign(:show_topup_modal, false) |> noreply()
  end

  def handle_event("hide-options", _params, socket) do
    socket |> assign(:options_modal, false) |> noreply()
  end

  def handle_event("select-tiqit-class", %{"tiqit-class-id" => tc_id}, socket) do
    tc =
      %TiqitClass{} =
      Arcade.get_tiqit_class_for_piece!(
        tc_id,
        socket.assigns.selected_piece,
        socket.assigns.group
      )

    socket |> assign(selected_tiqit_class: tc, options_modal: false) |> noreply()
  end

  def handle_event("show-topup-modal", _params, socket) do
    socket |> assign(:show_topup_modal, true) |> noreply()
  end

  def handle_event("show-options", _params, socket) do
    socket |> assign(:options_modal, true) |> noreply()
  end

  def handle_event("topup", _params, socket) do
    user = socket.assigns.current_scope.user

    Wallets.fake_topup(user)

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    # socket |> assign(:show_topup_modal, false) |> noreply()
    socket |> noreply()
  end

  def handle_event("purchase-tiqit", %{"tiqit-class-id" => tiqit_class_id}, socket) do
    tiqit_class =
      Arcade.get_tiqit_class_for_piece!(
        tiqit_class_id,
        socket.assigns.selected_piece,
        socket.assigns.group
      )

    :ok = Arcade.purchase_tiqit(socket.assigns.current_scope, tiqit_class)

    user = socket.assigns.current_scope.user

    Phoenix.PubSub.broadcast(Qlarius.PubSub, "wallet:#{user.id}", :update_balance)

    socket
    |> redirect(to: ~p"/widgets/content/#{socket.assigns.selected_piece.id}")
    |> noreply()
  end

  def handle_info(:update_balance, socket) do
    # Only update if mounted to prevent race conditions
    if socket.assigns[:mounted] do
      user = socket.assigns.current_scope.user
      scope = socket.assigns.current_scope

      # Only fetch balance if user exists
      balance = if user, do: Wallets.get_user_current_balance(user), else: socket.assigns.balance

      {:noreply,
       assign(socket,
         balance: balance,
         offered_amount: scope && scope.offered_amount
       )}
    else
      {:noreply, socket}
    end
  end

  defp class_type(tiqit_class, catalog) do
    cond do
      tiqit_class.content_piece_id -> catalog.piece_type
      tiqit_class.content_group_id -> catalog.group_type
      tiqit_class.catalog.id -> catalog.type
    end
  end
end
