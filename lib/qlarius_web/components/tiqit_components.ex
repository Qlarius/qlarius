defmodule QlariusWeb.TiqitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents,
    only: [show_modal: 2, hide_modal: 1, hide_modal: 2, modal: 1, icon: 1]

  import QlariusWeb.Helpers.ImageHelpers

  alias Phoenix.LiveView.JS
  alias Qlarius.Tiqit.Arcade.Arcade

  attr :status, :atom, required: true
  attr :preserved, :boolean, default: false

  def tiqit_status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm gap-1",
      case @status do
        :active -> "badge-success"
        :expired -> "badge-warning"
        :preserved -> "badge-info"
        :fleeted -> "badge-ghost"
        :undone -> "badge-error"
      end
    ]}>
      <.icon
        :if={@preserved && @status in [:active, :expired]}
        name="hero-shield-check-mini"
        class="w-3 h-3"
      />
      {status_display(@status)}
    </span>
    """
  end

  attr :tiqit, :any, required: true
  attr :status, :atom, required: true
  attr :fleet_after_hours, :integer, default: 24

  def tiqit_countdown(assigns) do
    assigns =
      assign(assigns, :fleet_at, fn ->
        if assigns.tiqit.expires_at do
          DateTime.add(assigns.tiqit.expires_at, assigns.fleet_after_hours, :hour)
        end
      end)

    ~H"""
    <span class="text-sm text-base-content/60">
      <%= case @status do %>
        <% :active -> %>
          <%= if @tiqit.expires_at do %>
            <QlariusWeb.Components.TiqitExpirationCountdown.badge
              expires_at={@tiqit.expires_at}
              label=""
              class="badge-ghost badge-sm"
            />
          <% else %>
            Lifetime access
          <% end %>
        <% :expired -> %>
          <% fleet_at = @fleet_at.() %>
          <%= if fleet_at && DateTime.compare(fleet_at, DateTime.utc_now()) == :gt do %>
            AutoFleet in
            <QlariusWeb.Components.TiqitExpirationCountdown.badge
              expires_at={fleet_at}
              label=""
              class="badge-ghost badge-sm"
            />
          <% else %>
            AutoFleet pending
          <% end %>
        <% :preserved -> %>
          Preserved — will not AutoFleet
        <% :fleeted -> %>
          Fleeted on {Calendar.strftime(@tiqit.disconnected_at, "%b %d, %Y")}
        <% :undone -> %>
          Undone on {Calendar.strftime(@tiqit.undone_at, "%b %d, %Y")}
      <% end %>
    </span>
    """
  end

  attr :tiqit, :any, required: true

  def tiqit_undo_countdown(assigns) do
    undo_window = Qlarius.System.get_global_variable_int("tiqit_undo_window_hours", 2)
    undo_deadline = DateTime.add(assigns.tiqit.purchased_at, undo_window, :hour)
    undo_available = Arcade.undo_available?(assigns.tiqit)

    assigns =
      assigns
      |> assign(:undo_window, undo_window)
      |> assign(:undo_deadline, undo_deadline)
      |> assign(:undo_available, undo_available)

    ~H"""
    <span class="text-sm text-base-content/60">
      <%= if @undo_available do %>
        expires in
        <QlariusWeb.Components.TiqitExpirationCountdown.badge
          expires_at={@undo_deadline}
          label=""
          class="badge-ghost badge-sm"
        />
      <% else %>
        {@undo_window}hr window closed
      <% end %>
    </span>
    """
  end

  attr :tiqit, :any, required: true
  attr :status, :atom, required: true
  attr :fleet_modal_id, :string, default: "fleet-confirm-modal"
  attr :undo_modal_id, :string, default: "undo-confirm-modal"
  attr :preserve_modal_id, :string, default: "preserve-confirm-modal"
  attr :unpreserve_modal_id, :string, default: "unpreserve-confirm-modal"

  def tiqit_actions(assigns) do
    assigns = assign(assigns, :undo_available, Arcade.undo_available?(assigns.tiqit))

    ~H"""
    <div class="flex flex-wrap gap-2">
      <%= case @status do %>
        <% s when s in [:active, :expired] -> %>
          <button
            :if={@undo_available}
            class="btn btn-sm btn-warning rounded-full"
            phx-click="prepare_undo"
            phx-value-id={@tiqit.id}
          >
            <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Undo
          </button>
          <%= if @tiqit.preserved do %>
            <button
              class="btn btn-sm btn-outline rounded-full"
              phx-click={
                JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
                  to: "##{@unpreserve_modal_id}-confirm-btn"
                )
                |> show_modal(@unpreserve_modal_id)
              }
            >
              <.icon name="hero-shield-exclamation" class="w-4 h-4" /> Unpreserve
            </button>
          <% else %>
            <button
              class="btn btn-sm btn-outline rounded-full"
              phx-click={
                JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
                  to: "##{@preserve_modal_id}-confirm-btn"
                )
                |> show_modal(@preserve_modal_id)
              }
            >
              <.icon name="hero-shield-check" class="w-4 h-4" /> Preserve
            </button>
          <% end %>
          <button
            class="btn btn-sm btn-error btn-outline rounded-full"
            phx-click={
              JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
                to: "##{@fleet_modal_id}-confirm-btn"
              )
              |> show_modal(@fleet_modal_id)
            }
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Fleet Now
          </button>
        <% :preserved -> %>
          <button
            :if={@undo_available}
            class="btn btn-sm btn-warning rounded-full"
            phx-click="prepare_undo"
            phx-value-id={@tiqit.id}
          >
            <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Undo
          </button>
          <button
            class="btn btn-sm btn-error btn-outline rounded-full"
            phx-click={
              JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
                to: "##{@fleet_modal_id}-confirm-btn"
              )
              |> show_modal(@fleet_modal_id)
            }
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Fleet Now
          </button>
        <% _ -> %>
      <% end %>
    </div>
    """
  end

  attr :tiqit, :any, required: true
  attr :fleet_after_hours, :integer, default: 24
  attr :fleet_modal_id, :string, default: "fleet-confirm-modal"
  attr :undo_modal_id, :string, default: "undo-confirm-modal"
  attr :preserve_modal_id, :string, default: "preserve-confirm-modal"
  attr :unpreserve_modal_id, :string, default: "unpreserve-confirm-modal"

  def tiqit_detail_card(assigns) do
    assigns =
      assigns
      |> assign(:status, Arcade.tiqit_status(assigns.tiqit))
      |> assign(:title, tiqit_title(assigns.tiqit))
      |> assign(:scope_label, tiqit_scope_label(assigns.tiqit))
      |> assign(:hierarchy, tiqit_hierarchy(assigns.tiqit))
      |> assign(:image_url, tiqit_image_url(assigns.tiqit))

    ~H"""
    <div class="tiqit-grid" data-status={@status}>
      <div class="tiqit-tl"></div>
      <div class="tiqit-top">
        <div class="float-right ml-3 mb-1 flex flex-col items-end gap-1">
          <.tiqit_status_badge status={@status} preserved={@tiqit.preserved} />
          <img
            src={@image_url}
            class="w-12 h-12 rounded object-cover shrink-0 border border-base-300/50"
          />
        </div>
        <div class="font-semibold mb-1">{@title}</div>
        <div class="text-sm text-base-content/60">{@scope_label}</div>
        <div :if={@hierarchy != []} class="text-xs text-base-content/50 mt-1">
          {Enum.join(@hierarchy, " › ")}
        </div>
      </div>
      <div class="tiqit-tr"></div>

      <div class="tiqit-notch tiqit-notch-l"><div></div></div>
      <div class="tiqit-perf"></div>
      <div class="tiqit-notch tiqit-notch-r"><div></div></div>

      <div class="tiqit-bl"></div>
      <div class="tiqit-bot">
        <div class="space-y-1 mb-2">
          <div class="flex items-center gap-2">
            <span class="text-xs text-base-content/50">Time Remaining:</span>
            <.tiqit_countdown tiqit={@tiqit} status={@status} fleet_after_hours={@fleet_after_hours} />
          </div>
          <div :if={@status in [:active, :expired]} class="flex items-center gap-2">
            <span class="text-xs text-base-content/50">Undo:</span>
            <.tiqit_undo_countdown tiqit={@tiqit} />
          </div>
        </div>

        <div class="text-xs text-base-content/40 mb-2">
          Purchased {Calendar.strftime(@tiqit.purchased_at, "%b %d, %Y at %I:%M %p")}
        </div>

        <.tiqit_actions
          tiqit={@tiqit}
          status={@status}
          fleet_modal_id={@fleet_modal_id}
          undo_modal_id={@undo_modal_id}
          preserve_modal_id={@preserve_modal_id}
          unpreserve_modal_id={@unpreserve_modal_id}
        />
      </div>
      <div class="tiqit-br"></div>
    </div>
    """
  end

  attr :id, :string, default: "fleet-confirm-modal"

  def fleet_confirm_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Fleet This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          This action is irreversible. All details of this purchase will be permanently severed from
          your account and will be unretrievable.
        </p>
        <div class="flex justify-end gap-2">
          <button class="btn btn-ghost" phx-click={hide_modal(@id)}>Cancel</button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-error"
            phx-click={JS.push("fleet_tiqit") |> hide_modal(@id)}
            phx-value-id=""
          >
            Fleet Now
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  attr :id, :string, default: "preserve-confirm-modal"

  def preserve_confirm_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Preserve This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          Preserving prevents this tiqit from being AutoFleeted after expiration.
          The purchase details will remain linked to your account indefinitely.
        </p>
        <p class="text-sm text-base-content/50 mb-4">
          You can unpreserve or manually fleet at any time.
        </p>
        <div class="flex justify-end gap-2">
          <button class="btn btn-ghost" phx-click={hide_modal(@id)}>Cancel</button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-primary"
            phx-click={JS.push("preserve_tiqit") |> hide_modal(@id)}
            phx-value-id=""
          >
            Preserve
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  attr :id, :string, default: "unpreserve-confirm-modal"

  def unpreserve_confirm_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Unpreserve This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          If this tiqit has expired, removing preservation will make it eligible
          for AutoFleet. It may be automatically fleeted and all purchase details
          permanently disconnected from your account.
        </p>
        <div class="flex justify-end gap-2">
          <button class="btn btn-ghost" phx-click={hide_modal(@id)}>Cancel</button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-warning"
            phx-click={JS.push("unpreserve_tiqit") |> hide_modal(@id)}
            phx-value-id=""
          >
            Unpreserve
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  attr :id, :string, default: "undo-confirm-modal"
  attr :undo_context, :map, default: nil

  def undo_confirm_modal(assigns) do
    ~H"""
    <.modal id={@id} on_cancel={JS.push("clear_undo_context")}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Undo This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          This will immediately refund the purchase amount and fleet the tiqit.
          The transaction will be reversed in your ledger.
        </p>

        <%= if @undo_context do %>
          <div class="bg-base-300 rounded-lg p-3 mb-4 text-sm space-y-2">
            <%= if @undo_context.limited? do %>
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Undos with {@undo_context.creator_name}:</span>
                <span class="font-semibold">{@undo_context.undos_remaining} of {@undo_context.undo_limit} remaining</span>
              </div>
              <div class="flex items-start gap-2 text-warning">
                <.icon name="hero-exclamation-triangle" class="w-4 h-4 mt-0.5 shrink-0" />
                <span>
                  Limited undos require a permanent counter linking you to this creator.
                  The content you purchased is not tracked, but the association to
                  <strong>{@undo_context.creator_name}</strong> cannot be removed.
                </span>
              </div>
            <% else %>
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Undos with {@undo_context.creator_name}:</span>
                <span class="font-semibold text-success">Unlimited</span>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="flex justify-end gap-2">
          <button
            class="btn btn-ghost"
            phx-click={JS.push("clear_undo_context") |> hide_modal(@id)}
          >
            Cancel
          </button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-warning"
            phx-click={JS.push("undo_tiqit") |> hide_modal(@id)}
            phx-value-id={if(@undo_context, do: @undo_context.tiqit_id, else: "")}
          >
            Undo & Refund
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  # Helpers

  defp tiqit_image_url(tiqit) do
    tc = tiqit.tiqit_class

    cond do
      tc.content_piece ->
        content_image_url(tc.content_piece, tc.content_piece.content_group)

      tc.content_group ->
        group_image_url(tc.content_group)

      tc.catalog ->
        catalog_image_url(tc.catalog)

      true ->
        placeholder_image_url()
    end
  end

  defp status_display(:active), do: "Active"
  defp status_display(:expired), do: "Expired"
  defp status_display(:preserved), do: "Preserved"
  defp status_display(:fleeted), do: "Fleeted"
  defp status_display(:undone), do: "Undone"

  def format_time_remaining(seconds) when is_integer(seconds) and seconds <= 0, do: "Expired"
  def format_time_remaining(:never), do: "Never"
  def format_time_remaining(:lifetime), do: "Lifetime"

  def format_time_remaining(seconds) when is_integer(seconds) do
    cond do
      seconds >= 86_400 -> "#{div(seconds, 86_400)}d"
      seconds >= 3_600 -> "#{div(seconds, 3_600)}h"
      seconds >= 60 -> "#{div(seconds, 60)}m"
      true -> "< 1m"
    end
  end

  def tiqit_title(tiqit) do
    tc = tiqit.tiqit_class

    cond do
      tc.content_piece -> tc.content_piece.title
      tc.content_group -> tc.content_group.title
      tc.catalog -> tc.catalog.name
      true -> "Unknown"
    end
  end

  defp tiqit_scope_label(tiqit) do
    tc = tiqit.tiqit_class
    catalog = tiqit_catalog(tiqit)

    cond do
      tc.content_piece_id && catalog ->
        catalog.piece_type |> to_string() |> String.capitalize()

      tc.content_group_id && catalog ->
        catalog.group_type |> to_string() |> String.capitalize()

      tc.catalog_id && catalog ->
        catalog.type |> to_string() |> String.capitalize()

      true ->
        ""
    end
  end

  defp tiqit_hierarchy(tiqit) do
    tc = tiqit.tiqit_class

    cond do
      tc.content_piece ->
        group = tc.content_piece.content_group
        catalog = group.catalog
        creator = catalog.creator
        [creator.name, catalog.name, group.title]

      tc.content_group ->
        catalog = tc.content_group.catalog
        creator = catalog.creator
        [creator.name, catalog.name]

      tc.catalog ->
        creator = tc.catalog.creator
        [creator.name]

      true ->
        []
    end
  end

  defp tiqit_catalog(tiqit) do
    tc = tiqit.tiqit_class

    cond do
      tc.content_piece && Ecto.assoc_loaded?(tc.content_piece.content_group) ->
        tc.content_piece.content_group.catalog

      tc.content_group && Ecto.assoc_loaded?(tc.content_group.catalog) ->
        tc.content_group.catalog

      tc.catalog ->
        tc.catalog

      true ->
        nil
    end
  end
end
