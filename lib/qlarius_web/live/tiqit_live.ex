defmodule QlariusWeb.TiqitLive do
  use QlariusWeb, :live_view

  import QlariusWeb.TiqitComponents

  alias QlariusWeb.Layouts
  alias Qlarius.Tiqit.Arcade.Arcade

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @valid_statuses ~w[active expired preserved fleeted undone all]

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope
    status = parse_status(params["status"])

    tiqits = Arcade.list_tiqits_by_status(scope, status)

    socket =
      socket
      |> assign(:current_path, "/tiqits")
      |> assign(:title, "Tiqits")
      |> assign(:status_filter, status)
      |> assign(:tiqits, tiqits)
      |> assign(:fleet_after_hours, scope.user.fleet_after_hours)
      |> assign(:undo_context, nil)
      |> assign(:fleeted_count, Arcade.count_fleeted_tiqits(scope))
      |> assign(:undone_count, Arcade.count_undone_tiqits(scope))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = parse_status(params["status"])
    scope = socket.assigns.current_scope
    tiqits = Arcade.list_tiqits_by_status(scope, status)

    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:tiqits, tiqits)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, push_patch(socket, to: ~p"/tiqits?status=#{status}")}
  end

  def handle_event("fleet_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.fleet_tiqit!(tiqit) do
      {:ok, _} ->
        {:noreply, reload_tiqits(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not fleet tiqit")}
    end
  end

  def handle_event("preserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, true) do
      {:ok, _} -> {:noreply, reload_tiqits(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not preserve tiqit")}
    end
  end

  def handle_event("unpreserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, false) do
      {:ok, _} -> {:noreply, reload_tiqits(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not unpreserve tiqit")}
    end
  end

  def handle_event("clear_undo_context", _params, socket) do
    {:noreply, assign(socket, :undo_context, nil)}
  end

  def handle_event("prepare_undo", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)
    undo_context = Arcade.get_undo_context(scope, tiqit)

    {:noreply, assign(socket, :undo_context, undo_context)}
  end

  def handle_event("undo_tiqit", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.undo_tiqit!(scope, tiqit) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:info, "Tiqit undone and refunded")
         |> reload_tiqits()}

      {:error, :undo_window_expired} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Undo window has expired")}

      {:error, :undo_limit_reached} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Undo limit reached for this creator")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Could not undo: #{reason}")}
    end
  end

  defp reload_tiqits(socket) do
    scope = socket.assigns.current_scope
    status = socket.assigns.status_filter
    tiqits = Arcade.list_tiqits_by_status(scope, status)

    socket
    |> assign(:tiqits, tiqits)
    |> assign(:fleeted_count, Arcade.count_fleeted_tiqits(scope))
    |> assign(:undone_count, Arcade.count_undone_tiqits(scope))
  end

  defp parse_status(nil), do: :all
  defp parse_status(s) when s in @valid_statuses, do: String.to_existing_atom(s)
  defp parse_status(_), do: :all

  defp filter_label(:all), do: "All"
  defp filter_label(:active), do: "Active"
  defp filter_label(:expired), do: "Expiring"
  defp filter_label(:preserved), do: "Preserved"
  defp filter_label(:fleeted), do: "Fleeted"
  defp filter_label(:undone), do: "Undone"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <div class="mb-6">
        <h2 class="text-xl font-bold mb-4">Tiqit Stash</h2>

        <div class="flex flex-wrap gap-2 mb-4">
          <button
            :for={status <- [:all, :active, :expired, :preserved, :fleeted, :undone]}
            phx-click="filter"
            phx-value-status={status}
            class={[
              "btn btn-sm",
              if(@status_filter == status, do: "btn-primary", else: "btn-ghost")
            ]}
          >
            {filter_label(status)}
          </button>
        </div>

        <%= if @status_filter in [:fleeted, :undone] do %>
          <div class="bg-base-200 rounded-lg p-6 text-center">
            <div class="text-4xl font-bold mb-2">
              {if @status_filter == :fleeted, do: @fleeted_count, else: @undone_count}
            </div>
            <div class="text-base-content/60 mb-4">
              {if @status_filter == :fleeted,
                do: "tiqits have been fleeted",
                else: "tiqits have been undone"}
            </div>
            <p class="text-sm text-base-content/40 max-w-sm mx-auto">
              <%= if @status_filter == :fleeted do %>
                Fleeted tiqits have been permanently disconnected from your account.
                No details are retrievable — that's the point.
              <% else %>
                Undone tiqits were refunded and fleeted. The purchase amount was
                returned to your wallet.
              <% end %>
            </p>
          </div>
        <% else %>
          <%= if @tiqits == [] do %>
            <div class="text-center text-base-content/50 py-8">
              No tiqits found for this filter.
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
              <.tiqit_detail_card
                :for={tiqit <- @tiqits}
                tiqit={tiqit}
                fleet_after_hours={@fleet_after_hours}
              />
            </div>
          <% end %>
        <% end %>
      </div>

    </Layouts.mobile>

    <.fleet_confirm_modal />
    <.preserve_confirm_modal />
    <.undo_confirm_modal undo_context={@undo_context} />
    <div :if={@undo_context} id="undo-modal-trigger" phx-mounted={show_modal("undo-confirm-modal")} />
    """
  end
end
