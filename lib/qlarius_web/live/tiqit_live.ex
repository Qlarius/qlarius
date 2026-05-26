defmodule QlariusWeb.TiqitLive do
  use QlariusWeb, :live_view

  import QlariusWeb.TiqitComponents
  import QlariusWeb.PWAHelpers

  alias QlariusWeb.Layouts
  alias Qlarius.Tiqit.Arcade.Arcade

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @valid_statuses ~w[active expired preserved fleeted all]

  @impl true
  def mount(params, session, socket) do
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
      |> assign_stash_filter_counts(scope)
      |> init_pwa_assigns(session)

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
     |> assign(:tiqits, tiqits)
     |> assign_stash_filter_counts(scope)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, push_patch(socket, to: ~p"/tiqits?status=#{status}")}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
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
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not mark tiqit")}
    end
  end

  def handle_event("unpreserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, false) do
      {:ok, _} -> {:noreply, reload_tiqits(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not unmark tiqit")}
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
         |> put_flash(:info, "Tiqit refunded successfully")
         |> reload_tiqits()}

      {:error, :undo_window_expired} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Refund window has expired")}

      {:error, :undo_limit_reached} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Refund limit reached for this creator")}

      {:error, :not_refundable} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Free tiqits cannot be refunded")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:undo_context, nil)
         |> put_flash(:error, "Could not refund: #{reason}")}
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
    |> assign_stash_filter_counts(scope)
  end

  defp assign_stash_filter_counts(socket, scope) do
    socket
    |> assign(:active_count, Arcade.count_active_tiqits(scope))
    |> assign(:preserved_count, Arcade.count_preserved_tiqits(scope))
    |> assign(:fleeting_count, Arcade.count_fleeting_tiqits(scope))
  end

  defp filter_badge(assigns, :active) when assigns.active_count > 0 do
    %{count: assigns.active_count, variant: :success}
  end

  defp filter_badge(assigns, :preserved) when assigns.preserved_count > 0 do
    %{count: assigns.preserved_count, variant: :info}
  end

  defp filter_badge(assigns, :expired) when assigns.fleeting_count > 0 do
    %{count: assigns.fleeting_count, variant: :warning}
  end

  defp filter_badge(_assigns, _status), do: nil

  defp pill_count_badge_class(:success),
    do: "badge badge-sm ml-2 rounded px-2 py-3 !border-0 !bg-success !text-success-content"

  defp pill_count_badge_class(:info),
    do: "badge badge-sm ml-2 rounded px-2 py-3 !border-0 !bg-info !text-info-content"

  defp pill_count_badge_class(:warning),
    do: "badge badge-sm ml-2 rounded px-2 py-3 !border-0 !bg-warning !text-warning-content"

  defp parse_status(nil), do: :all
  defp parse_status(s) when s in @valid_statuses, do: String.to_existing_atom(s)
  defp parse_status(_), do: :all

  defp filter_label(:all), do: "All"
  defp filter_label(:active), do: "Active"
  defp filter_label(:expired), do: "Fleeting"
  defp filter_label(:fleeted), do: "Fleeted"
  defp filter_label(:preserved), do: "Marked"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tiqit-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="mb-6">
          <h2 class="text-xl font-bold mb-4">Stash</h2>

          <div class="mb-4 overflow-x-auto">
            <.pill_join_selector label="Stash filter" class="min-w-max">
              <.pill_join_item
                :for={status <- [:all, :active, :preserved, :expired, :fleeted]}
                active={@status_filter == status}
                class="gap-2"
                phx-click="filter"
                phx-value-status={status}
                aria-pressed={to_string(@status_filter == status)}
              >
                {filter_label(status)}
                <%= if badge = filter_badge(assigns, status) do %>
                  <span class={pill_count_badge_class(badge.variant)}>
                    {badge.count}
                  </span>
                <% end %>
              </.pill_join_item>
            </.pill_join_selector>
          </div>

          <%= if @status_filter == :fleeted do %>
            <div class="bg-base-200 rounded-lg p-6 text-center">
              <div class="text-4xl font-bold mb-2">
                {@fleeted_count + @undone_count}
              </div>
              <div class="text-base-content/60 mb-4">
                tiqits have been fleeted
              </div>
              <div class="flex justify-center gap-6 mb-4">
                <div class="text-center">
                  <div class="text-2xl font-bold">{@fleeted_count}</div>
                  <div class="text-xs text-base-content/50">fleeted</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-bold">{@undone_count}</div>
                  <div class="text-xs text-base-content/50">refunded</div>
                </div>
              </div>
              <p class="text-sm text-base-content/40 max-w-sm mx-auto">
                Fleeted tiqits have been permanently disconnected from your account.
                No details are retrievable. (That's the point.)
              </p>
            </div>
          <% else %>
            <%= if @tiqits == [] do %>
              <div class="text-center text-base-content/50 py-8">
                No tiqits found for this filter.
              </div>
            <% else %>
              <div class="grid grid-cols-1 items-start md:grid-cols-2 xl:grid-cols-3 gap-6">
                <.tiqit_detail_card
                  :for={tiqit <- @tiqits}
                  tiqit={tiqit}
                  user={@current_scope.user}
                  fleet_after_hours={@fleet_after_hours}
                />
              </div>
            <% end %>
          <% end %>
        </div>
      </Layouts.mobile>

      <.fleet_confirm_modal />
      <.preserve_confirm_modal />
      <.unpreserve_confirm_modal />
      <.undo_confirm_modal undo_context={@undo_context} />
      <div :if={@undo_context} id="undo-modal-trigger" phx-mounted={show_modal("undo-confirm-modal")} />
    </div>
    """
  end
end
