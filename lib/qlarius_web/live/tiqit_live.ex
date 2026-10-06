defmodule QlariusWeb.TiqitLive do
  use QlariusWeb, :live_view

  import QlariusWeb.TiqitComponents
  import QlariusWeb.PWAHelpers

  alias QlariusWeb.Layouts
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.ContentSharing

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @valid_statuses ~w[active expired preserved fleeted gifted all]

  @impl true
  def mount(params, session, socket) do
    scope = socket.assigns.current_scope
    status = parse_status(params["status"])

    tiqits = Arcade.list_tiqits_by_status(scope, status)

    socket =
      socket
      |> assign(:current_path, "/tiqits")
      |> assign(:title, "Stash")
      |> assign(:status_filter, status)
      |> assign(:tiqits, tiqits)
      |> assign(:gifts, load_gifts(scope, status))
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
     |> assign(:gifts, load_gifts(scope, status))
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
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not keep tiqit")}
    end
  end

  def handle_event("unpreserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, false) do
      {:ok, _} -> {:noreply, reload_tiqits(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not stop keeping tiqit")}
    end
  end

  def handle_event("clear_undo_context", _params, socket) do
    {:noreply, assign(socket, :undo_context, nil)}
  end

  def handle_event("revoke-gift", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case ContentSharing.revoke_gift(scope, String.to_integer(id)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gift withdrawn — credit returned to your wallet")
         |> reload_tiqits()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You can't withdraw this gift")}

      {:error, :not_revokable} ->
        {:noreply, put_flash(socket, :error, "This gift can no longer be withdrawn")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not withdraw gift")}
    end
  end

  def handle_event("copy_success", _params, socket) do
    {:noreply, put_flash(socket, :info, "Copied to clipboard")}
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
    |> assign(:gifts, load_gifts(scope, status))
    |> assign(:fleeted_count, Arcade.count_fleeted_tiqits(scope))
    |> assign(:undone_count, Arcade.count_undone_tiqits(scope))
    |> assign_stash_filter_counts(scope)
  end

  defp assign_stash_filter_counts(socket, scope) do
    socket
    |> assign(:active_count, Arcade.count_active_tiqits(scope))
    |> assign(:preserved_count, Arcade.count_preserved_tiqits(scope))
    |> assign(:fleeting_count, Arcade.count_fleeting_tiqits(scope))
    |> assign(:gifted_count, ContentSharing.count_pending_sender_gifts(scope))
  end

  defp load_gifts(scope, status) when status in [:gifted, :all],
    do: ContentSharing.list_sender_gifts(scope)

  defp load_gifts(_scope, _status), do: []

  # Counts stay neutral; the filter name says which state it is.
  defp filter_count(assigns, :active), do: assigns.active_count
  defp filter_count(assigns, :preserved), do: assigns.preserved_count
  defp filter_count(assigns, :expired), do: assigns.fleeting_count
  defp filter_count(assigns, :gifted), do: assigns.gifted_count
  defp filter_count(_assigns, _status), do: 0

  defp parse_status(nil), do: :all
  defp parse_status(s) when s in @valid_statuses, do: String.to_existing_atom(s)
  defp parse_status(_), do: :all

  defp filter_label(:all), do: "All"
  defp filter_label(:active), do: "Active"
  defp filter_label(:expired), do: "Fleeting"
  defp filter_label(:fleeted), do: "Fleeted"
  defp filter_label(:preserved), do: "Kept"
  defp filter_label(:gifted), do: "Gifted"

  defp stash_empty?(assigns) do
    assigns.tiqits == [] and (assigns.status_filter != :all or assigns.gifts == [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tiqit-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="flex flex-col gap-6">
          <div class="stash-filter-scroll">
            <.pill_join_selector label="Stash filter" class="min-w-max">
              <.pill_join_item
                :for={status <- [:all, :active, :expired, :fleeted, :preserved, :gifted]}
                active={@status_filter == status}
                class="gap-2"
                phx-click="filter"
                phx-value-status={status}
                aria-pressed={to_string(@status_filter == status)}
              >
                {filter_label(status)}
                <span
                  :if={filter_count(assigns, status) > 0}
                  class="pill-join-count badge badge-sm ml-2 rounded px-2 py-3 !border-0 tabular-amount"
                >
                  {filter_count(assigns, status)}
                </span>
              </.pill_join_item>
            </.pill_join_selector>
          </div>

          <%= if @status_filter == :gifted do %>
            <%= if @gifts == [] do %>
              <p class="mobile-page-intro text-center py-8">
                You haven't gifted any content yet.
              </p>
            <% else %>
              <div class="tiqit-stash-grid grid grid-cols-[repeat(auto-fill,minmax(min(19rem,100%),1fr))] gap-6 items-stretch">
                <.tiqit_detail_card
                  :for={gift <- @gifts}
                  gift={gift}
                  user={@current_scope.user}
                />
              </div>
            <% end %>
          <% else %>
            <%= if @status_filter == :fleeted do %>
              <.surface_panel class="text-center">
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
              </.surface_panel>
            <% else %>
              <%= if stash_empty?(assigns) do %>
                <p class="mobile-page-intro text-center py-8">
                  No tiqits found for this filter.
                </p>
              <% else %>
                <div class="tiqit-stash-grid grid grid-cols-[repeat(auto-fill,minmax(min(19rem,100%),1fr))] gap-6 items-stretch">
                  <.tiqit_detail_card
                    :for={tiqit <- @tiqits}
                    tiqit={tiqit}
                    user={@current_scope.user}
                    fleet_after_hours={@fleet_after_hours}
                  />
                  <.tiqit_detail_card
                    :for={gift <- @gifts}
                    :if={@status_filter == :all}
                    gift={gift}
                    user={@current_scope.user}
                  />
                </div>
              <% end %>
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
