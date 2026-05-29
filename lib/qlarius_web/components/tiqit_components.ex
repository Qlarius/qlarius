defmodule QlariusWeb.TiqitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents,
    only: [show_modal: 2, hide_modal: 1, hide_modal: 2, modal: 1, icon: 1]

  import QlariusWeb.Helpers.ImageHelpers

  alias Phoenix.LiveView.JS
  alias Qlarius.Tiqit.Arcade.Arcade

  @tiqit_card_shell_class "overflow-hidden rounded-lg shadow-sm"

  # Status badges use a combinable model:
  # - Primary: Active (green) or Expired (yellow) — based on whether access has lapsed
  # - Fleeting (orange): only if expired AND not marked — subject to auto-fleet
  # - Marked (blue): if the user has bookmarked the tiqit to keep it
  # Fleeted/refunded tiqits render as blank anonymous cards and don't use these badges.
  attr :status, :atom, required: true
  attr :preserved, :boolean, default: false

  def tiqit_status_badges(assigns) do
    ~H"""
    <.tiqit_primary_status_badge status={@status} />
    <span :if={@status == :expired && !@preserved} class="badge badge-md badge-warning text-xs">
      Fleeting
    </span>
    <span :if={@preserved} class="badge badge-md badge-info gap-1 text-xs">
      <.icon name="hero-bookmark-mini" class="w-3.5 h-3.5" /> Marked
    </span>
    """
  end

  attr :status, :atom, required: true

  defp tiqit_primary_status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-md text-xs",
      if(@status == :active,
        do: "!border-0 !bg-sponster-500 !text-primary-content",
        else: "badge-warning"
      )
    ]}>
      {if @status == :active, do: "Active", else: "Expired"}
    </span>
    """
  end

  attr :tiqit, :any, required: true
  attr :status, :atom, required: true
  attr :fleet_after_hours, :integer, default: 24
  attr :user, :any, default: nil
  attr :fleet_modal_id, :string, default: "fleet-confirm-modal"
  attr :undo_modal_id, :string, default: "undo-confirm-modal"
  attr :preserve_modal_id, :string, default: "preserve-confirm-modal"
  attr :unpreserve_modal_id, :string, default: "unpreserve-confirm-modal"

  def tiqit_status_and_actions(assigns) do
    undo_window = Qlarius.System.get_global_variable_int("tiqit_undo_window_hours", 2)
    undo_deadline = DateTime.add(assigns.tiqit.purchased_at, undo_window, :hour)

    assigns =
      assigns
      |> assign(:undo_deadline, undo_deadline)
      |> assign(:refund_locked?, not is_nil(assigns.tiqit.refund_locked_at))
      |> assign(:content_path, tiqit_content_path(assigns.tiqit))
      |> assign(:scope_label, tiqit_scope_label(assigns.tiqit))
      |> assign(:show_preserve_cell?, !(assigns.status == :expired && assigns.tiqit.preserved))
      |> assign(:show_refund_cell?, !assigns.tiqit.refund_locked_at && Arcade.undo_available?(assigns.tiqit))

    ~H"""
    <div class="tiqit-actions flex w-full flex-col gap-3">
      <div class="border-b border-base-300/30 pb-2 text-sm text-base-content/50 dark:border-base-content/15">
        Purchased {format_purchased_at(@tiqit.purchased_at, @user)}
      </div>

      <.link
        :if={@status in [:active, :expired] && @content_path}
        navigate={@content_path}
        class={[tiqit_action_btn_base(), "btn-primary gap-2 text-base font-semibold"]}
      >
        <.icon name="hero-play" class="h-5 w-5 shrink-0" />
        Go to {if @scope_label != "", do: @scope_label, else: "Content"}
      </.link>

      <%= if @status in [:active, :expired] do %>
        <div :if={@refund_locked?} class="flex items-center gap-1 text-xs text-base-content/40">
          <.icon name="hero-lock-closed-mini" class="h-4 w-4 shrink-0" />
          Discount applied to TiqitUp
        </div>

        <div class="flex w-full gap-2">
          <div :if={@show_refund_cell?} class="min-w-0 flex-1">
            <.tiqit_refund_cell tiqit={@tiqit} undo_deadline={@undo_deadline} />
          </div>

          <div :if={@show_preserve_cell?} class="min-w-0 flex-1">
            <.tiqit_preserve_cell
              tiqit={@tiqit}
              preserve_modal_id={@preserve_modal_id}
              unpreserve_modal_id={@unpreserve_modal_id}
            />
          </div>

          <div class="min-w-0 flex-1">
            <.tiqit_fleet_cell tiqit={@tiqit} fleet_modal_id={@fleet_modal_id} />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :tiqit, :any, required: true
  attr :undo_deadline, :any, required: true

  defp tiqit_refund_cell(assigns) do
    ~H"""
    <button
      class={[tiqit_action_btn_base(), "btn-outline flex-col gap-0.5"]}
      phx-click="prepare_undo"
      phx-value-id={@tiqit.id}
    >
      <span class="flex items-center gap-1 text-sm font-semibold leading-tight">
        <.icon name="hero-arrow-uturn-left" class="h-4 w-4 shrink-0" /> Refund
      </span>
      <QlariusWeb.Components.TiqitExpirationCountdown.text
        expires_at={@undo_deadline}
        format={:hms}
        class="text-[10px] font-normal leading-tight text-base-content/60"
      />
    </button>
    """
  end

  attr :tiqit, :any, required: true
  attr :preserve_modal_id, :string, required: true
  attr :unpreserve_modal_id, :string, required: true

  defp tiqit_preserve_cell(assigns) do
    ~H"""
    <%= if @tiqit.preserved do %>
      <button
        class={[tiqit_action_btn_base(), "btn-outline"]}
        phx-click={
          JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
            to: "##{@unpreserve_modal_id}-confirm-btn"
          )
          |> show_modal(@unpreserve_modal_id)
        }
      >
        <span class="flex items-center gap-1 text-sm font-semibold leading-tight">
          <.icon name="hero-bookmark-slash" class="h-4 w-4 shrink-0" /> Unmark
        </span>
      </button>
    <% else %>
      <button
        class={[tiqit_action_btn_base(), "btn-outline"]}
        phx-click={
          JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
            to: "##{@preserve_modal_id}-confirm-btn"
          )
          |> show_modal(@preserve_modal_id)
        }
      >
        <span class="flex items-center gap-1 text-sm font-semibold leading-tight">
          <.icon name="hero-bookmark" class="h-4 w-4 shrink-0" /> Mark
        </span>
      </button>
    <% end %>
    """
  end

  attr :tiqit, :any, required: true
  attr :fleet_modal_id, :string, required: true

  defp tiqit_fleet_cell(assigns) do
    ~H"""
    <button
      class={[tiqit_action_btn_base(), "btn-error btn-outline"]}
      phx-click={
        JS.set_attribute({"phx-value-id", to_string(@tiqit.id)},
          to: "##{@fleet_modal_id}-confirm-btn"
        )
        |> show_modal(@fleet_modal_id)
      }
    >
      <span class="flex items-center gap-1 text-sm font-semibold leading-tight">
        <.icon name="hero-trash" class="h-4 w-4 shrink-0" /> Fleet
      </span>
    </button>
    """
  end

  attr :tiqit, :any, required: true
  attr :user, :any, default: nil
  attr :fleet_after_hours, :integer, default: 24
  attr :fleet_modal_id, :string, default: "fleet-confirm-modal"
  attr :undo_modal_id, :string, default: "undo-confirm-modal"
  attr :preserve_modal_id, :string, default: "preserve-confirm-modal"
  attr :unpreserve_modal_id, :string, default: "unpreserve-confirm-modal"

  def tiqit_detail_card(assigns) do
    status = Arcade.tiqit_status(assigns.tiqit)
    tiqit = assigns.tiqit

    fleet_at_deadline =
      if status == :expired && !tiqit.preserved && tiqit.expires_at do
        DateTime.add(tiqit.expires_at, assigns.fleet_after_hours, :hour)
      end

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:fleet_at_deadline, fleet_at_deadline)
      |> assign(:title, tiqit_title(assigns.tiqit))
      |> assign(:scope_label, tiqit_scope_label(assigns.tiqit))
      |> assign(:content_summary, tiqit_content_summary(assigns.tiqit))
      |> assign(:hierarchy, tiqit_hierarchy(assigns.tiqit))
      |> assign(:image_url, tiqit_image_url(assigns.tiqit))
      |> assign(:tiqit_card_shell_class, @tiqit_card_shell_class)

    ~H"""
    <div class={@tiqit_card_shell_class}>
      <div class="tiqit-grid" data-status={@status} data-preserved={to_string(@tiqit.preserved)}>
        <div class="tiqit-tl"></div>
        <div class="tiqit-top">
          <div class="flex items-start gap-3">
            <img
              src={@image_url}
              alt=""
              class="h-24 w-24 shrink-0 rounded-lg border border-base-300/50 object-cover"
            />
          <div class="min-w-0 flex-1 text-left">
            <div
              :if={@scope_label != ""}
              class="mb-1 text-xs font-extralight uppercase leading-relaxed tracking-widest text-base-content/55"
            >
              {@scope_label}
            </div>
            <div class="text-base font-semibold leading-snug">{@title}</div>
            <div :if={@content_summary} class="mt-0.5 text-sm text-base-content/50">
              {@content_summary}
            </div>
            <div :if={@hierarchy != []} class="mt-1 text-sm text-base-content/50">
              {Enum.join(@hierarchy, " › ")}
            </div>
          </div>
          </div>

          <%= if @status in [:active, :expired] do %>
          <div class="mt-4 flex flex-wrap items-center gap-x-2 gap-y-1.5 border-t border-base-300/25 pt-3 dark:border-base-content/15">
            <%= cond do %>
              <% @status == :active -> %>
                <.tiqit_primary_status_badge status={:active} />
                <span class="text-sm text-base-content/55">
                  Expires in{" "}
                  <span class="text-base-content/80">
                    <%= if @tiqit.expires_at do %>
                      <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={
                        @tiqit.expires_at
                      } />
                    <% else %>
                      <span class="font-semibold">Lifetime access</span>
                    <% end %>
                  </span>
                </span>
              <% @status == :expired && @tiqit.preserved -> %>
                <div class="flex flex-wrap items-center gap-2">
                  <.tiqit_status_badges status={:expired} preserved={true} />
                </div>
              <% @status == :expired -> %>
                <.tiqit_primary_status_badge status={:expired} />
                <span class="text-sm text-base-content/55">
                  Auto-Fleets in{" "}
                  <span class="text-base-content/80">
                    <%= if @fleet_at_deadline &&
                           DateTime.compare(@fleet_at_deadline, DateTime.utc_now()) == :gt do %>
                      <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={
                        @fleet_at_deadline
                      } />
                    <% else %>
                      <span class="font-semibold">AutoFleet pending</span>
                    <% end %>
                  </span>
                </span>
              <% true -> %>
            <% end %>
          </div>
          <% end %>
        </div>
        <div class="tiqit-tr"></div>

        <div class="tiqit-notch tiqit-notch-l">
          <div></div>
        </div>
        <div class="tiqit-perf"></div>
        <div class="tiqit-notch tiqit-notch-r">
          <div></div>
        </div>

        <div class="tiqit-bl"></div>
        <div class="tiqit-bot">
          <details class="tiqit-tail-details min-w-0" phx-hook="TiqitTailDetails" id={"tiqit-tail-#{@tiqit.id}"}>
            <summary
              class="tiqit-tail-details-summary cursor-pointer list-none [&::-webkit-details-marker]:hidden"
              aria-label="Show or hide purchase details and actions"
            >
              <div class="tiqit-tail-fold">
                <span class="tiqit-tail-toggle">
                  <span class="tiqit-tail-expand-hit">
                    <.icon
                      name="hero-chevron-down"
                      class="tiqit-tail-details-chevron h-5 w-5 shrink-0 text-base-content/55"
                    />
                  </span>
                </span>
              </div>
            </summary>
            <div class="tiqit-tail-details-body">
              <.tiqit_status_and_actions
                tiqit={@tiqit}
                status={@status}
                user={@user}
                fleet_after_hours={@fleet_after_hours}
                fleet_modal_id={@fleet_modal_id}
                undo_modal_id={@undo_modal_id}
                preserve_modal_id={@preserve_modal_id}
                unpreserve_modal_id={@unpreserve_modal_id}
              />
            </div>
          </details>
        </div>
        <div class="tiqit-br"></div>
      </div>
    </div>
    """
  end

  attr :gift, :any, required: true
  attr :user, :any, default: nil

  def gifted_tiqit_card(assigns) do
    gift = assigns.gift
    invitation = gift.share_invitation

    {status_label, status_class} = gift_status_display(gift.will_call_status)

    title =
      cond do
        gift.content_piece && gift.content_piece.title -> gift.content_piece.title
        gift.content_group && gift.content_group.title -> gift.content_group.title
        true -> "Gift"
      end

    scope_label = if gift.content_group, do: gift.content_group.title, else: ""

    assigns =
      assigns
      |> assign(:invitation, invitation)
      |> assign(:status_label, status_label)
      |> assign(:status_class, status_class)
      |> assign(:title, title)
      |> assign(:scope_label, scope_label)
      |> assign(:image_url, gift_image_url(gift))
      |> assign(:amount_label, format_gift_amount(gift.amount))
      |> assign(:tiqit_card_shell_class, @tiqit_card_shell_class)

    ~H"""
    <div class={[@tiqit_card_shell_class, "border border-base-300/50 bg-base-100 p-4"]}>
      <div class="flex items-start gap-3">
        <img
          src={@image_url}
          alt=""
          class="h-20 w-20 shrink-0 rounded-lg border border-base-300/50 object-cover"
        />
        <div class="min-w-0 flex-1 text-left">
          <div class="mb-1 flex items-center gap-2">
            <span class="badge badge-sm gap-1 !border-0 !bg-primary !text-primary-content">
              <.icon name="hero-gift-mini" class="h-3.5 w-3.5" /> Gifted
            </span>
            <span class={["badge badge-sm", @status_class]}>{@status_label}</span>
          </div>
          <div
            :if={@scope_label != "" && @scope_label != @title}
            class="text-xs font-extralight uppercase tracking-widest text-base-content/55"
          >
            {@scope_label}
          </div>
          <div class="text-base font-semibold leading-snug">{@title}</div>
          <div class="mt-0.5 text-sm text-base-content/50">{@amount_label} prepaid</div>

          <div
            :if={@gift.will_call_status in ["at_will_call", "claim_check_required"]}
            class="mt-1 text-sm text-base-content/55"
          >
            <%= if @invitation && @invitation.gift_expires_at &&
                   DateTime.compare(@invitation.gift_expires_at, DateTime.utc_now()) == :gt do %>
              Claim window ends in{" "}
              <span class="text-base-content/80">
                <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={
                  @invitation.gift_expires_at
                } />
              </span>
            <% else %>
              Awaiting pickup
            <% end %>
          </div>

          <div
            :if={@gift.will_call_status == "expired"}
            class="mt-1 text-sm text-base-content/55"
          >
            Unclaimed — amount refunded to your wallet
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp gift_status_display("picked_up"), do: {"Claimed", "badge-success"}
  defp gift_status_display("expired"), do: {"Expired", "badge-ghost"}
  defp gift_status_display("pulled"), do: {"Withdrawn", "badge-ghost"}
  defp gift_status_display(_), do: {"Awaiting pickup", "badge-warning"}

  defp gift_image_url(gift) do
    cond do
      gift.content_piece && gift.content_group ->
        content_image_url(gift.content_piece, gift.content_group)

      gift.content_piece ->
        content_image_url(gift.content_piece, nil)

      gift.content_group ->
        group_image_url(gift.content_group)

      true ->
        placeholder_image_url()
    end
  end

  defp format_gift_amount(nil), do: "$0.00"

  defp format_gift_amount(%Decimal{} = amount) do
    "$" <> (amount |> Decimal.round(2) |> Decimal.to_string())
  end

  attr :disconnect_reason, :atom, default: :fleeted

  def tiqit_fleeted_card(assigns) do
    status = if assigns.disconnect_reason == :undone, do: :undone, else: :fleeted

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:tiqit_card_shell_class, @tiqit_card_shell_class)

    ~H"""
    <div class={@tiqit_card_shell_class}>
      <div class="tiqit-grid" data-status={@status}>
      <div class="tiqit-tl"></div>
      <div class="tiqit-top">
        <div class="flex flex-col items-center justify-center py-4 text-center">
          <.icon
            name={if @status == :undone, do: "hero-arrow-uturn-left", else: "hero-shield-check"}
            class="w-8 h-8 text-base-content/30 mb-2"
          />
          <p class="text-sm font-medium text-base-content/60">
            <%= if @status == :undone do %>
              Tiqit Refunded
            <% else %>
              Tiqit Fleeted
            <% end %>
          </p>
        </div>
      </div>
      <div class="tiqit-tr"></div>

      <div class="tiqit-notch tiqit-notch-l">
        <div></div>
      </div>
      <div class="tiqit-perf"></div>
      <div class="tiqit-notch tiqit-notch-r">
        <div></div>
      </div>

      <div class="tiqit-bl"></div>
      <div class="tiqit-bot">
        <p class="text-xs text-base-content/40 text-center">
          <%= if @status == :undone do %>
            This tiqit was refunded and fleeted. Purchase details have been disconnected.
          <% else %>
            This tiqit has been fleeted. Purchase details are no longer available.
          <% end %>
        </p>
      </div>
        <div class="tiqit-br"></div>
      </div>
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
            Fleet
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
        <h3 class="text-lg font-bold mb-2">Mark This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          Marking prevents this tiqit from being AutoFleeted after expiration.
          The purchase details will remain linked to your account indefinitely.
        </p>
        <p class="text-sm text-base-content/50 mb-4">
          You can unmark or manually fleet at any time.
        </p>
        <div class="flex justify-end gap-2">
          <button class="btn btn-ghost" phx-click={hide_modal(@id)}>Cancel</button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-primary"
            phx-click={JS.push("preserve_tiqit") |> hide_modal(@id)}
            phx-value-id=""
          >
            Mark
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
        <h3 class="text-lg font-bold mb-2">Unmark This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          If this tiqit has expired, removing the mark will make it eligible
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
            Unmark
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
        <h3 class="text-lg font-bold mb-2">Refund This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          This will immediately refund the purchase amount and fleet the tiqit.
          The transaction will be reversed in your ledger.
        </p>

        <%= if @undo_context do %>
          <div class="bg-base-300 rounded-lg p-3 mb-4 text-sm space-y-2">
            <%= if @undo_context.limited? do %>
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Refunds with {@undo_context.creator_name}:</span>
                <span class="font-semibold">
                  {@undo_context.undos_remaining} of {@undo_context.undo_limit} remaining
                </span>
              </div>
              <div class="flex items-start gap-2 text-warning">
                <.icon name="hero-exclamation-triangle" class="w-4 h-4 mt-0.5 shrink-0" />
                <span>
                  Limited refunds require a permanent counter linking you to this creator.
                  The content you purchased is not tracked, but the association to
                  <strong>{@undo_context.creator_name}</strong>
                  cannot be removed.
                </span>
              </div>
            <% else %>
              <div class="flex justify-between items-center">
                <span class="text-base-content/70">Refunds with {@undo_context.creator_name}:</span>
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
            class="btn btn-primary"
            phx-click={JS.push("undo_tiqit") |> hide_modal(@id)}
            phx-value-id={if(@undo_context, do: @undo_context.tiqit_id, else: "")}
          >
            Refund & Fleet
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  # Helpers

  defp tiqit_action_btn_base do
    "btn btn-md flex min-h-[3.75rem] w-full items-center justify-center rounded-full px-2 py-1.5"
  end

  defp format_purchased_at(datetime, user) do
    Qlarius.DateTime.format_for_user(datetime, user, :standard_no_tz)
  end

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

  def tiqit_scope_label(tiqit) do
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

  # Returns the main-app path for the content a tiqit unlocks.
  # Piece-level: /content/:id — the content controller checks tiqit validity
  # and serves content directly if active, or redirects to arcade if not.
  # Group/catalog: /arqade/... pages for browsing and selecting content.
  def tiqit_content_path(tiqit) do
    tc = tiqit.tiqit_class

    cond do
      tc.content_piece_id -> "/content/#{tc.content_piece_id}"
      tc.content_group_id -> "/arqade/group/#{tc.content_group_id}"
      tc.catalog_id -> "/arqade/catalog/#{tc.catalog_id}"
      true -> nil
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

  defp tiqit_content_summary(tiqit) do
    tc = tiqit.tiqit_class
    catalog = tiqit_catalog(tiqit)

    cond do
      tc.content_group_id && catalog ->
        count = Arcade.count_group_pieces(tc.content_group_id)
        "#{count} #{label(catalog.piece_type, count)}"

      tc.catalog_id && catalog ->
        {group_count, piece_count} = Arcade.catalog_content_counts(tc.catalog_id)

        "#{piece_count} #{label(catalog.piece_type, piece_count)} in #{group_count} #{label(catalog.group_type, group_count)}"

      true ->
        nil
    end
  end

  # Explicit {singular, plural} for every Catalog enum value (piece_type,
  # group_type, and type). When a new enum value is added to
  # Qlarius.Tiqit.Arcade.Catalog, add its entry here — English pluralization
  # is too irregular for safe rule-based derivation ("Series" stays "Series",
  # "Class" becomes "Classes", etc.). The label/2 helper below uses this map
  # to render counts on tiqit cards (e.g. "8 Episodes in 2 Seasons").
  @label_plurals %{
    # piece_types — see Catalog @piece_types
    article: {"Article", "Articles"},
    episode: {"Episode", "Episodes"},
    chapter: {"Chapter", "Chapters"},
    song: {"Song", "Songs"},
    piece: {"Piece", "Pieces"},
    lesson: {"Lesson", "Lessons"},
    segment: {"Segment", "Segments"},
    # group_types — see Catalog @group_types
    section: {"Section", "Sections"},
    show: {"Show", "Shows"},
    season: {"Season", "Seasons"},
    series: {"Series", "Series"},
    album: {"Album", "Albums"},
    book: {"Book", "Books"},
    class: {"Class", "Classes"},
    # catalog types — see Catalog @types
    site: {"Site", "Sites"},
    catalog: {"Catalog", "Catalogs"},
    studio: {"Studio", "Studios"},
    collection: {"Collection", "Collections"},
    curriculum: {"Curriculum", "Curriculums"},
    semester: {"Semester", "Semesters"}
  }

  defp label(type_atom, count) do
    case Map.get(@label_plurals, type_atom) do
      {singular, _plural} when count == 1 -> singular
      {_singular, plural} -> plural
      nil -> type_atom |> to_string() |> String.capitalize()
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
