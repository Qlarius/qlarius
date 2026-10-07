defmodule QlariusWeb.TiqitLive do
  use QlariusWeb, :live_view

  import QlariusWeb.TiqitComponents
  import QlariusWeb.PWAHelpers

  alias Phoenix.LiveView.AsyncResult
  alias QlariusWeb.Layouts
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.ContentSharing

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @valid_statuses ~w[active expired preserved fleeted gifted all]

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:current_path, "/tiqits")
     |> assign(:title, "Stash")
     |> assign(:fleet_after_hours, socket.assigns.current_scope.user.fleet_after_hours)
     |> assign(:undo_context, nil)
     |> init_pwa_assigns(session)}
  end

  # The stash depends on the filter in the URL, so it loads here, with
  # `assign_async/3`: the dead render and the wait for the socket show the
  # skeleton from `<.async_result>`'s :loading slot, as Arqade's pages do. On a
  # filter change the current cards stay until the new ones arrive
  # (assign_async keeps the previous result).
  @impl true
  def handle_params(params, _uri, socket) do
    status = parse_status(params["status"])
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign_async(:stash, fn -> {:ok, %{stash: load_stash(scope, status)}} end)}
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
        {:noreply, reload_stash(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not fleet tiqit")}
    end
  end

  def handle_event("preserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, true) do
      {:ok, _} -> {:noreply, reload_stash(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not keep tiqit")}
    end
  end

  def handle_event("unpreserve_tiqit", %{"id" => id}, socket) do
    tiqit = Qlarius.Repo.get!(Qlarius.Tiqit.Arcade.Tiqit, id)

    case Arcade.preserve_tiqit(tiqit, false) do
      {:ok, _} -> {:noreply, reload_stash(socket)}
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
         |> reload_stash()}

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
         |> reload_stash()}

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

  # After an action on a card: reload in place (no skeleton)
  defp reload_stash(socket) do
    %{current_scope: scope, status_filter: status, stash: stash} = socket.assigns
    assign(socket, :stash, AsyncResult.ok(stash, load_stash(scope, status)))
  end

  # Everything the page shows for one filter: the cards and every count
  defp load_stash(scope, status) do
    %{
      tiqits: Arcade.list_tiqits_by_status(scope, status),
      gifts: load_gifts(scope, status),
      fleeted_count: Arcade.count_fleeted_tiqits(scope),
      undone_count: Arcade.count_undone_tiqits(scope),
      active_count: Arcade.count_active_tiqits(scope),
      preserved_count: Arcade.count_preserved_tiqits(scope),
      fleeting_count: Arcade.count_fleeting_tiqits(scope),
      gifted_count: ContentSharing.count_pending_sender_gifts(scope)
    }
  end

  defp load_gifts(scope, status) when status in [:gifted, :all],
    do: ContentSharing.list_sender_gifts(scope)

  defp load_gifts(_scope, _status), do: []

  # Counts stay neutral; the filter name says which state it is. None while
  # the stash first loads.
  defp filter_count(%AsyncResult{ok?: true, result: stash}, status) do
    case status do
      :active -> stash.active_count
      :preserved -> stash.preserved_count
      :expired -> stash.fleeting_count
      :gifted -> stash.gifted_count
      _ -> 0
    end
  end

  defp filter_count(_stash, _status), do: 0

  defp parse_status(nil), do: :all
  defp parse_status(s) when s in @valid_statuses, do: String.to_existing_atom(s)
  defp parse_status(_), do: :all

  defp filter_label(:all), do: "All"
  defp filter_label(:active), do: "Active"
  defp filter_label(:expired), do: "Fleeting"
  defp filter_label(:fleeted), do: "Fleeted"
  defp filter_label(:preserved), do: "Kept"
  defp filter_label(:gifted), do: "Gifted"

  defp stash_empty?(stash, status) do
    stash.tiqits == [] and (status != :all or stash.gifts == [])
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
                  :if={filter_count(@stash, status) > 0}
                  class="pill-join-count badge badge-sm ml-2 rounded px-2 py-3 !border-0 tabular-amount"
                >
                  {filter_count(@stash, status)}
                </span>
              </.pill_join_item>
            </.pill_join_selector>
          </div>

          <.async_result :let={stash} assign={@stash}>
            <:loading>
              <.tiqit_stash_skeleton />
            </:loading>
            <:failed>
              <p class="mobile-page-intro text-center py-8">
                Couldn't load your tiqits. Try refreshing.
              </p>
            </:failed>
            <%= if @status_filter == :gifted do %>
              <%= if stash.gifts == [] do %>
                <p class="mobile-page-intro text-center py-8">
                  You haven't gifted any content yet.
                </p>
              <% else %>
                <div class="tiqit-stash-grid grid grid-cols-[repeat(auto-fill,minmax(min(19rem,100%),1fr))] gap-6 items-stretch">
                  <.tiqit_detail_card
                    :for={gift <- stash.gifts}
                    gift={gift}
                    user={@current_scope.user}
                  />
                </div>
              <% end %>
            <% else %>
              <%= if @status_filter == :fleeted do %>
                <.surface_panel class="text-center">
                  <div class="text-4xl font-bold mb-2">
                    {stash.fleeted_count + stash.undone_count}
                  </div>
                  <div class="text-base-content/60 mb-4">
                    tiqits have been fleeted
                  </div>
                  <div class="flex justify-center gap-6 mb-4">
                    <div class="text-center">
                      <div class="text-2xl font-bold">{stash.fleeted_count}</div>
                      <div class="text-xs text-base-content/50">fleeted</div>
                    </div>
                    <div class="text-center">
                      <div class="text-2xl font-bold">{stash.undone_count}</div>
                      <div class="text-xs text-base-content/50">refunded</div>
                    </div>
                  </div>
                  <p class="text-sm text-base-content/40 max-w-sm mx-auto">
                    Fleeted tiqits have been permanently disconnected from your account.
                    No details are retrievable. (That's the point.)
                  </p>
                </.surface_panel>
              <% else %>
                <%= if stash_empty?(stash, @status_filter) do %>
                  <p class="mobile-page-intro text-center py-8">
                    No tiqits found for this filter.
                  </p>
                <% else %>
                  <div class="tiqit-stash-grid grid grid-cols-[repeat(auto-fill,minmax(min(19rem,100%),1fr))] gap-6 items-stretch">
                    <.tiqit_detail_card
                      :for={tiqit <- stash.tiqits}
                      tiqit={tiqit}
                      user={@current_scope.user}
                      fleet_after_hours={@fleet_after_hours}
                    />
                    <.tiqit_detail_card
                      :for={gift <- stash.gifts}
                      :if={@status_filter == :all}
                      gift={gift}
                      user={@current_scope.user}
                    />
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </.async_result>
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
