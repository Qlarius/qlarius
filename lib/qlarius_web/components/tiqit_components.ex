defmodule QlariusWeb.TiqitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents,
    only: [show_modal: 2, hide_modal: 1, hide_modal: 2, modal: 1, icon: 1]

  import QlariusWeb.Helpers.ImageHelpers

  alias Phoenix.LiveView.JS
  alias Qlarius.ContentSharing
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias QlariusWeb.Widgets.Arcade.Paths

  @tiqit_card_shell_class "tiqit-card-shell overflow-hidden rounded-lg"

  attr :tone, :atom, required: true, values: [:live, :warn, :muted, :done]
  slot :inner_block, required: true

  # One status line per card, a coloured dot and plain words, in place of
  # stacked badges:
  # - Active: access is live (Tiqit orange), with time left or lifetime
  # - Fleeting: already expired and counting down to AutoFleet (red)
  # - Kept: expired but kept, so it won't AutoFleet (grey)
  # - Gifted: by pickup state (claimed = green)
  # Fleeted/refunded tiqits render as blank anonymous cards and have no line.
  defp tiqit_status_line(assigns) do
    ~H"""
    <p class="tiqit-status">
      <span class={["tiqit-status__dot", "is-#{@tone}"]} aria-hidden="true"></span>
      <span class="min-w-0">{render_slot(@inner_block)}</span>
    </p>
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
      |> assign(:show_preserve_cell?, !(assigns.status == :expired && assigns.tiqit.preserved))
      |> assign(
        :show_refund_cell?,
        !assigns.tiqit.refund_locked_at && Arcade.undo_available?(assigns.tiqit)
      )

    ~H"""
    <%!-- Opened from "⋯" on the stub; Open itself sits on the stub --%>
    <div class="tiqit-actions flex w-full flex-col gap-3">
      <p class="text-sm text-base-content/55">
        Purchased {format_purchased_at(@tiqit.purchased_at, @user)}
      </p>

      <%= if @status in [:active, :expired] do %>
        <div :if={@refund_locked?} class="flex items-center gap-1 text-xs text-base-content/40">
          <.icon name="hero-lock-closed-mini" class="h-4 w-4 shrink-0" /> Discount applied to TiqitUp
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
          <.icon name="hero-bookmark-slash" class="h-4 w-4 shrink-0" /> Don't Keep
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
          <.icon name="hero-bookmark" class="h-4 w-4 shrink-0" /> Keep
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

  attr :tiqit, :any, default: nil
  attr :gift, :any, default: nil
  attr :user, :any, default: nil
  attr :fleet_after_hours, :integer, default: 24
  attr :fleet_modal_id, :string, default: "fleet-confirm-modal"
  attr :undo_modal_id, :string, default: "undo-confirm-modal"
  attr :preserve_modal_id, :string, default: "preserve-confirm-modal"
  attr :unpreserve_modal_id, :string, default: "unpreserve-confirm-modal"
  attr :gift_read_only, :boolean, default: false

  def tiqit_detail_card(%{gift: %{} = gift} = assigns) do
    invitation = gift.share_invitation
    revokable? = gift.will_call_status in ["at_will_call", "claim_check_required"]
    grid_status = "gifted"

    assigns =
      assigns
      |> assign(:card_kind, :gift)
      |> assign(:card_id, gift.id)
      |> assign(:grid_status, grid_status)
      |> assign(:title, gift_title(gift))
      |> assign(:title_path, gift_title_path(gift))
      |> assign(:scope_label, gift_scope_label(gift))
      |> assign(:content_summary, gift_content_summary(gift))
      |> assign(:hierarchy, gift_hierarchy(gift))
      |> assign(:image_url, gift_image_url(gift))
      |> assign(:invitation, invitation)
      |> assign(:revokable?, revokable?)
      |> assign(:amount_label, format_gift_amount(gift.amount))
      |> assign(
        :invitation_message,
        if(revokable?, do: ContentSharing.sender_gift_invitation_message(gift))
      )
      |> assign(:tiqit_card_shell_class, @tiqit_card_shell_class)
      |> assign(:tiqit, nil)
      |> assign(:fleet_at_deadline, nil)
      |> assign(:gift_read_only, Map.get(assigns, :gift_read_only, false))

    ~H"""
    <.tiqit_detail_card_shell
      card_id={@card_id}
      grid_status={@grid_status}
      preserved={false}
      gift?={true}
      title={@title}
      title_path={@title_path}
      scope_label={@scope_label}
      content_summary={@content_summary}
      hierarchy={@hierarchy}
      image_url={@image_url}
      tiqit_card_shell_class={@tiqit_card_shell_class}
      read_only={@gift_read_only}
    >
      <:status_row>
        <.gift_status_line gift={@gift} invitation={@invitation} read_only={@gift_read_only} />
      </:status_row>
      <:read_only_tail :if={
        @gift_read_only && @gift.will_call_status in ["at_will_call", "claim_check_required"]
      }>
        <.gift_claim_window_line invitation={@invitation} />
      </:read_only_tail>
      <:stub :if={!@gift_read_only}>
        <p class="tiqit-stub__meta" title={"Gifted " <> format_purchased_at(@gift.inserted_at, @user)}>
          Gifted {format_stub_date(@gift.inserted_at, @user)} ·
          <span class="tabular-amount">{@amount_label}</span>
          prepaid
        </p>
      </:stub>
      <:tail :if={!@gift_read_only && @revokable?}>
        <.tiqit_gift_status_and_actions
          gift={@gift}
          user={@user}
          amount_label={@amount_label}
          revokable?={@revokable?}
          invitation_message={@invitation_message}
        />
      </:tail>
    </.tiqit_detail_card_shell>
    """
  end

  def tiqit_detail_card(%{tiqit: tiqit} = assigns) when not is_nil(tiqit) do
    status = Arcade.tiqit_status(tiqit)

    fleet_at_deadline =
      if status == :expired && !tiqit.preserved && tiqit.expires_at do
        DateTime.add(tiqit.expires_at, assigns.fleet_after_hours, :hour)
      end

    assigns =
      assigns
      |> assign(:card_kind, :tiqit)
      |> assign(:card_id, tiqit.id)
      |> assign(:grid_status, Atom.to_string(status))
      |> assign(:status, status)
      |> assign(:fleet_at_deadline, fleet_at_deadline)
      |> assign(:title, tiqit_title(tiqit))
      |> assign(:title_path, tiqit_title_path(tiqit))
      |> assign(:scope_label, tiqit_scope_label(tiqit))
      |> assign(:content_summary, tiqit_content_summary(tiqit))
      |> assign(:hierarchy, tiqit_hierarchy(tiqit))
      |> assign(:image_url, tiqit_image_url(tiqit))
      |> assign(:tiqit_card_shell_class, @tiqit_card_shell_class)
      |> assign(:gift, nil)

    ~H"""
    <.tiqit_detail_card_shell
      card_id={@card_id}
      grid_status={@grid_status}
      preserved={@tiqit.preserved}
      gift?={false}
      title={@title}
      title_path={@title_path}
      scope_label={@scope_label}
      content_summary={@content_summary}
      hierarchy={@hierarchy}
      image_url={@image_url}
      tiqit_card_shell_class={@tiqit_card_shell_class}
    >
      <:status_row :if={@status in [:active, :expired]}>
        <%= cond do %>
          <% @status == :active -> %>
            <.tiqit_status_line tone={:live}>
              <b>Active</b>
              ·
              <%= if @tiqit.expires_at do %>
                expires in
                <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={@tiqit.expires_at} />
              <% else %>
                lifetime access
              <% end %>
              <span :if={@tiqit.preserved}>· Kept</span>
            </.tiqit_status_line>
          <% @tiqit.preserved -> %>
            <.tiqit_status_line tone={:muted}>
              <b>Kept</b>
              <span :if={@tiqit.expires_at}>
                · expired {Qlarius.DateTime.format_for_user(@tiqit.expires_at, @user, :date_only)}
              </span>
            </.tiqit_status_line>
          <% true -> %>
            <.tiqit_status_line tone={:warn}>
              <b>Fleeting</b>
              ·
              <%= if @fleet_at_deadline &&
                     DateTime.compare(@fleet_at_deadline, DateTime.utc_now()) == :gt do %>
                auto-fleets in
                <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={@fleet_at_deadline} />
              <% else %>
                AutoFleet pending
              <% end %>
            </.tiqit_status_line>
        <% end %>
      </:status_row>
      <:stub :if={@status in [:active, :expired]}>
        <.tiqit_stub_meta tiqit={@tiqit} user={@user} />
      </:stub>
      <:stub_action :if={@status in [:active, :expired]}>
        <.tiqit_open_link tiqit={@tiqit} status={@status} />
      </:stub_action>
      <:tail>
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
      </:tail>
    </.tiqit_detail_card_shell>
    """
  end

  def tiqit_detail_card(_assigns) do
    raise ArgumentError, "tiqit_detail_card requires either :tiqit or :gift"
  end

  attr :card_id, :any, required: true
  attr :grid_status, :string, required: true
  attr :preserved, :boolean, default: false
  attr :gift?, :boolean, default: false
  attr :read_only, :boolean, default: false
  attr :title, :string, required: true
  attr :title_path, :string, default: nil
  attr :scope_label, :string, default: ""
  attr :content_summary, :string, default: nil
  attr :hierarchy, :list, default: []
  attr :image_url, :string, required: true
  attr :tiqit_card_shell_class, :string, required: true
  slot :status_row
  slot :stub
  slot :stub_action
  slot :tail
  slot :read_only_tail

  defp tiqit_detail_card_shell(assigns) do
    assigns =
      assigns
      |> assign(
        :kind_line,
        Enum.join(
          Enum.reject([assigns.scope_label, assigns.content_summary], &(&1 in [nil, ""])),
          " · "
        )
      )
      |> assign(:source_parts, compact_source_parts(assigns.hierarchy))
      |> assign(
        :source_full,
        assigns.hierarchy |> source_parts() |> Enum.map_join(" › ", & &1.name)
      )
      |> assign(
        :more_id,
        "tiqit-more-#{if assigns.gift?, do: "gift", else: "tiqit"}-#{assigns.card_id}"
      )

    ~H"""
    <div class={@tiqit_card_shell_class}>
      <div
        class="tiqit-grid"
        data-status={@grid_status}
        data-preserved={to_string(@preserved)}
        data-gift={to_string(@gift?)}
      >
        <div class="tiqit-tl"></div>
        <div class="tiqit-top">
          <div class="flex items-start gap-3">
            <img
              src={@image_url}
              alt=""
              class="h-16 w-16 shrink-0 rounded-lg border border-base-300/50 object-cover"
            />
            <div class="min-w-0 flex-1 text-left">
              <p :if={@kind_line != ""} class="text-xs text-base-content/55">{@kind_line}</p>
              <.link
                :if={@title_path}
                navigate={@title_path}
                class="tiqit-content-link line-clamp-2 text-base font-semibold leading-snug"
                title={@title}
              >
                {@title}
              </.link>
              <p
                :if={!@title_path}
                class="line-clamp-2 text-base font-semibold leading-snug"
                title={@title}
              >
                {@title}
              </p>
              <p
                :if={@source_parts != []}
                class="mt-0.5 truncate text-sm text-base-content/55"
                title={@source_full}
              >
                <%= for {part, idx} <- Enum.with_index(@source_parts) do %>
                  <span :if={idx > 0}> › </span>
                  <.link :if={part.path} navigate={part.path} class="tiqit-content-link">
                    {part.name}
                  </.link>
                  <span :if={!part.path}>{part.name}</span>
                <% end %>
              </p>
            </div>
          </div>

          <div :if={@status_row != []} class="tiqit-status-row">
            {render_slot(@status_row)}
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
        <div class={["tiqit-bot", @read_only && "tiqit-bot--read-only"]}>
          <%= if @read_only do %>
            <div class="tiqit-tail-read-only">
              {render_slot(@read_only_tail)}
            </div>
          <% else %>
            <div :if={@stub != []} class="tiqit-stub">
              {render_slot(@stub)}
              <div class="tiqit-stub__actions">
                <button
                  :if={@tail != []}
                  type="button"
                  class="tiqit-stub-btn tiqit-more-btn"
                  aria-label="Purchase details and actions"
                  aria-expanded="false"
                  aria-controls={@more_id}
                  phx-click={toggle_more(@more_id)}
                >
                  <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
                </button>
                {render_slot(@stub_action)}
              </div>
            </div>
            <div :if={@tail != []} id={@more_id} class="tiqit-more" inert>
              <div class="tiqit-more__clip">
                <div class="tiqit-more__body">
                  {render_slot(@tail)}
                </div>
              </div>
            </div>
          <% end %>
        </div>
        <div class="tiqit-br"></div>
      </div>
    </div>
    """
  end

  attr :gift, :any, required: true
  attr :user, :any, default: nil
  attr :amount_label, :string, required: true
  attr :revokable?, :boolean, default: false
  attr :invitation_message, :string, default: nil

  defp tiqit_gift_status_and_actions(assigns) do
    ~H"""
    <div class="tiqit-actions flex w-full flex-col gap-3">
      <%= if @revokable? do %>
        <textarea
          :if={@invitation_message}
          id={"gift-invitation-#{@gift.id}"}
          readonly
          rows="5"
          class="textarea textarea-bordered tiqit-invitation-text w-full text-xs text-left"
        ><%= @invitation_message %></textarea>

        <div class="flex w-full gap-2">
          <button
            :if={@invitation_message}
            type="button"
            id={"copy-gift-invitation-#{@gift.id}"}
            phx-hook="CopyToClipboard"
            data-target={"gift-invitation-#{@gift.id}"}
            class={[tiqit_action_btn_base(), "btn-outline flex-1 gap-2 text-sm font-semibold"]}
          >
            <.icon name="hero-clipboard-document" class="h-4 w-4 shrink-0" /> Copy invitation
          </button>

          <button
            type="button"
            phx-click="revoke-gift"
            phx-value-id={@gift.id}
            data-confirm="Withdraw this gift? The amount will return to your wallet."
            class={[
              tiqit_action_btn_base(),
              "btn-error btn-outline flex-1 gap-2 text-sm font-semibold"
            ]}
          >
            <.icon name="hero-x-circle" class="h-4 w-4 shrink-0" /> Revoke
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  attr :gift, :any, required: true
  attr :invitation, :any, default: nil
  attr :read_only, :boolean, default: false

  # The recipient's read-only view (Arqade gift landing) shows the claim
  # countdown in its tail and keeps a neutral dot, as Arqade can be embedded.
  defp gift_status_line(assigns) do
    claim_ends_at =
      with %{gift_expires_at: %DateTime{} = at} <- assigns.invitation,
           :gt <- DateTime.compare(at, DateTime.utc_now()) do
        at
      else
        _ -> nil
      end

    tone =
      cond do
        assigns.read_only -> :muted
        assigns.gift.will_call_status == "picked_up" -> :done
        assigns.gift.will_call_status in ["expired", "pulled"] -> :muted
        true -> :live
      end

    assigns = assign(assigns, claim_ends_at: claim_ends_at, tone: tone)

    ~H"""
    <.tiqit_status_line tone={@tone}>
      <b>Gifted</b>
      ·
      <%= case @gift.will_call_status do %>
        <% "picked_up" -> %>
          claimed
        <% "expired" -> %>
          unclaimed, refunded
        <% "pulled" -> %>
          withdrawn, refunded
        <% _ -> %>
          <%= if @claim_ends_at && !@read_only do %>
            claim ends in
            <QlariusWeb.Components.TiqitExpirationCountdown.text expires_at={@claim_ends_at} />
          <% else %>
            awaiting pickup
          <% end %>
      <% end %>
    </.tiqit_status_line>
    """
  end

  attr :invitation, :any, default: nil

  # The recipient's read-only tail on the Arqade gift landing, while the gift
  # waits to be claimed.
  defp gift_claim_window_line(assigns) do
    ~H"""
    <span class="tiqit-tail-read-only-claim text-sm font-medium text-primary">
      Claim window ends in{" "}
      <%= if @invitation && @invitation.gift_expires_at &&
             DateTime.compare(@invitation.gift_expires_at, DateTime.utc_now()) == :gt do %>
        <QlariusWeb.Components.TiqitExpirationCountdown.text
          expires_at={@invitation.gift_expires_at}
          class="font-semibold text-primary"
        />
      <% else %>
        <span class="font-semibold">Awaiting pickup</span>
      <% end %>
    </span>
    """
  end

  defp gift_title(gift) do
    cond do
      gift.content_piece && gift.content_piece.title != "" -> gift.content_piece.title
      gift.content_group && gift.content_group.title != "" -> gift.content_group.title
      true -> "Gift"
    end
  end

  defp gift_title_path(gift) do
    cond do
      gift.content_piece && gift.content_piece.title != "" ->
        arqade_path(:piece, gift.content_piece)

      gift.content_group && gift.content_group.title != "" ->
        arqade_path(:group, gift.content_group)

      true ->
        nil
    end
  end

  defp gift_scope_label(gift) do
    catalog = gift_catalog(gift)

    cond do
      gift.content_piece_id && catalog ->
        catalog.piece_type |> to_string() |> String.capitalize()

      gift.content_group_id && catalog ->
        catalog.group_type |> to_string() |> String.capitalize()

      true ->
        ""
    end
  end

  defp gift_hierarchy(gift) do
    cond do
      gift.content_piece && Ecto.assoc_loaded?(gift.content_piece.content_group) ->
        group = gift.content_piece.content_group
        catalog = group.catalog
        creator = catalog.creator

        [
          content_link(creator.name, arqade_path(:creator, creator)),
          content_link(catalog.name, arqade_path(:catalog, catalog)),
          content_link(group.title, arqade_path(:group, group))
        ]

      gift.content_group && Ecto.assoc_loaded?(gift.content_group.catalog) ->
        catalog = gift.content_group.catalog
        creator = catalog.creator

        [
          content_link(creator.name, arqade_path(:creator, creator)),
          content_link(catalog.name, arqade_path(:catalog, catalog))
        ]

      true ->
        []
    end
  end

  defp gift_content_summary(gift) do
    catalog = gift_catalog(gift)

    case gift_tiqit_class(gift) do
      %TiqitClass{} = tc when not is_nil(catalog) ->
        gift_content_summary_for_class(tc, catalog)

      _ ->
        if gift.content_piece_id, do: nil, else: legacy_gift_content_summary(gift, catalog)
    end
  end

  defp gift_tiqit_class(%{tiqit_class: %TiqitClass{} = tc}), do: tc

  defp gift_tiqit_class(%{share_invitation: %{tiqit_class: %TiqitClass{} = tc}}), do: tc

  defp gift_tiqit_class(_), do: nil

  defp gift_content_summary_for_class(%TiqitClass{content_piece_id: id}, _catalog)
       when not is_nil(id),
       do: nil

  defp gift_content_summary_for_class(%TiqitClass{content_group_id: id}, catalog)
       when not is_nil(id) do
    count = Arcade.count_group_pieces(id)
    "#{count} #{Catalog.type_label(catalog.piece_type, count)}"
  end

  defp gift_content_summary_for_class(%TiqitClass{catalog_id: id}, catalog) when not is_nil(id) do
    {group_count, piece_count} = Arcade.catalog_content_counts(id)

    "#{piece_count} #{Catalog.type_label(catalog.piece_type, piece_count)} in #{group_count} #{Catalog.type_label(catalog.group_type, group_count)}"
  end

  defp gift_content_summary_for_class(_, _), do: nil

  defp legacy_gift_content_summary(gift, catalog) do
    if gift.content_group_id && catalog do
      count = Arcade.count_group_pieces(gift.content_group_id)
      "#{count} #{Catalog.type_label(catalog.piece_type, count)}"
    end
  end

  defp gift_catalog(gift) do
    cond do
      gift.content_piece && Ecto.assoc_loaded?(gift.content_piece.content_group) ->
        gift.content_piece.content_group.catalog

      gift.content_group && Ecto.assoc_loaded?(gift.content_group.catalog) ->
        gift.content_group.catalog

      true ->
        nil
    end
  end

  defp gift_image_url(gift) do
    cond do
      gift.content_piece && Ecto.assoc_loaded?(gift.content_piece.content_group) ->
        content_image_url(gift.content_piece, gift.content_piece.content_group)

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

  attr :count, :integer, default: 6

  @doc """
  First-load placeholder for the Stash grid: blank tickets (same shell, notches
  and tear line as `tiqit_detail_card/1`) with DaisyUI `.skeleton` bones, as
  Arqade's loading states use.
  """
  def tiqit_stash_skeleton(assigns) do
    assigns = assign(assigns, :tiqit_card_shell_class, @tiqit_card_shell_class)

    ~H"""
    <div
      id="tiqit-stash-skeleton"
      class="tiqit-stash-grid grid grid-cols-[repeat(auto-fill,minmax(min(19rem,100%),1fr))] gap-6 items-stretch"
      aria-busy="true"
      aria-label="Loading tiqits"
    >
      <div :for={_ <- 1..@count} class={@tiqit_card_shell_class} aria-hidden="true">
        <div class="tiqit-grid" data-status="skeleton">
          <div class="tiqit-tl"></div>
          <div class="tiqit-top">
            <div class="flex items-start gap-3">
              <div class="skeleton h-16 w-16 shrink-0 rounded-lg"></div>
              <div class="flex min-w-0 flex-1 flex-col gap-2 pt-0.5">
                <div class="skeleton h-3 w-1/4"></div>
                <div class="skeleton h-4 w-4/5"></div>
                <div class="skeleton h-3 w-1/2"></div>
              </div>
            </div>
            <div class="tiqit-status-row">
              <div class="skeleton h-4 w-3/5"></div>
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
            <div class="tiqit-stub">
              <div class="skeleton h-4 w-2/5"></div>
              <div class="tiqit-stub__actions">
                <div class="skeleton h-8 w-8 rounded-full"></div>
                <div class="skeleton h-8 w-16 rounded-full"></div>
              </div>
            </div>
          </div>
          <div class="tiqit-br"></div>
        </div>
      </div>
    </div>
    """
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
    <.modal id={@id} on_cancel={hide_modal(@id)}>
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
    <.modal id={@id} on_cancel={hide_modal(@id)}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Keep This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          Keeping prevents this tiqit from being AutoFleeted after expiration.
          The purchase details will remain linked to your account indefinitely.
        </p>
        <p class="text-sm text-base-content/50 mb-4">
          You can stop keeping it or manually fleet at any time.
        </p>
        <div class="flex justify-end gap-2">
          <button class="btn btn-ghost" phx-click={hide_modal(@id)}>Cancel</button>
          <button
            id={"#{@id}-confirm-btn"}
            class="btn btn-primary"
            phx-click={JS.push("preserve_tiqit") |> hide_modal(@id)}
            phx-value-id=""
          >
            Keep
          </button>
        </div>
      </div>
    </.modal>
    """
  end

  attr :id, :string, default: "unpreserve-confirm-modal"

  def unpreserve_confirm_modal(assigns) do
    ~H"""
    <.modal id={@id} on_cancel={hide_modal(@id)}>
      <div class="p-6">
        <h3 class="text-lg font-bold mb-2">Don't Keep This Tiqit?</h3>
        <p class="text-base-content/70 mb-4">
          If this tiqit has expired, no longer keeping it will make it eligible
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
            Don't Keep
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
    <.modal id={@id} on_cancel={JS.push("clear_undo_context") |> hide_modal(@id)}>
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

  attr :tiqit, :any, required: true
  attr :user, :any, default: nil

  # The ticket stub's line: when it was bought and for how much
  defp tiqit_stub_meta(assigns) do
    ~H"""
    <p
      class="tiqit-stub__meta"
      title={"Purchased " <> format_purchased_at(@tiqit.purchased_at, @user)}
    >
      Bought {format_stub_date(@tiqit.purchased_at, @user)}<span :if={@tiqit.price}>
        · <span class="tabular-amount">{format_gift_amount(@tiqit.price)}</span></span>
    </p>
    """
  end

  attr :tiqit, :any, required: true
  attr :status, :atom, required: true

  # Open is the main action on a live tiqit; on an expired one it's quieter, as
  # the content page sends you to the Arqade to buy again.
  defp tiqit_open_link(assigns) do
    assigns = assign(assigns, :content_path, tiqit_content_path(assigns.tiqit))

    ~H"""
    <.link
      :if={@content_path}
      navigate={@content_path}
      class={["tiqit-stub-btn tiqit-stub-btn--open", @status == :active && "is-primary"]}
    >
      Open <.icon name="hero-chevron-right-mini" class="h-4 w-4" />
    </.link>
    """
  end

  # "⋯" opens and closes the panel below the stub line. JS commands survive
  # LiveView patches, so the panel stays as the user left it.
  defp toggle_more(id) do
    JS.toggle_class("is-open")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"})
    |> JS.toggle_class("is-open", to: "##{id}")
    |> JS.toggle_attribute({"inert", ""}, to: "##{id}")
  end

  # Helpers

  defp tiqit_action_btn_base do
    "btn btn-md flex min-h-[3.75rem] w-full items-center justify-center rounded-full px-2 py-1.5"
  end

  defp format_purchased_at(datetime, user) do
    Qlarius.DateTime.format_for_user(datetime, user, :standard_no_tz)
  end

  # "Oct 3" this year, "Oct 03, 2025" before
  defp format_stub_date(datetime, user) do
    format = if datetime.year == DateTime.utc_now().year, do: :month_day, else: :date_only
    Qlarius.DateTime.format_for_user(datetime, user, format)
  end

  # The source line: creator › catalog › group, without repeats (a creator
  # whose catalog has the same name), and only the ends when there are three.
  # Each part keeps the arqade path for its own level.
  defp compact_source_parts(hierarchy) do
    case source_parts(hierarchy) do
      [first, _ | _] = parts when length(parts) > 2 -> [first, List.last(parts)]
      parts -> parts
    end
  end

  defp source_parts(hierarchy) do
    hierarchy
    |> Enum.reject(&(is_nil(&1) or &1.name in [nil, ""]))
    |> Enum.dedup_by(&(&1.name |> String.trim() |> String.downcase()))
  end

  defp content_link(name, path) when is_binary(name) and name != "", do: %{name: name, path: path}
  defp content_link(_, _), do: nil

  defp arqade_path(:creator, %{id: id}) when not is_nil(id), do: Paths.creator("", id)
  defp arqade_path(:catalog, %{id: id}) when not is_nil(id), do: Paths.catalog("", id)
  defp arqade_path(:group, %{id: id}) when not is_nil(id), do: Paths.group("", id)
  defp arqade_path(:piece, %{id: id}) when not is_nil(id), do: Paths.piece("", id)
  defp arqade_path(_, _), do: nil

  defp tiqit_image_url(tiqit) do
    cond do
      piece = Tiqit.content_piece(tiqit) ->
        content_image_url(piece, piece.content_group)

      group = Tiqit.content_group(tiqit) ->
        group_image_url(group)

      catalog = Tiqit.catalog(tiqit) ->
        catalog_image_url(catalog)

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
    cond do
      piece = Tiqit.content_piece(tiqit) -> piece.title
      group = Tiqit.content_group(tiqit) -> group.title
      catalog = Tiqit.catalog(tiqit) -> catalog.name
      true -> "Unknown"
    end
  end

  defp tiqit_title_path(tiqit) do
    cond do
      piece = Tiqit.content_piece(tiqit) -> arqade_path(:piece, piece)
      group = Tiqit.content_group(tiqit) -> arqade_path(:group, group)
      catalog = Tiqit.catalog(tiqit) -> arqade_path(:catalog, catalog)
      true -> nil
    end
  end

  def tiqit_scope_label(tiqit) do
    catalog = tiqit_catalog(tiqit)

    cond do
      Tiqit.scope_piece_id(tiqit) && catalog ->
        catalog.piece_type |> to_string() |> String.capitalize()

      Tiqit.scope_group_id(tiqit) && catalog ->
        catalog.group_type |> to_string() |> String.capitalize()

      Tiqit.scope_catalog_id(tiqit) && catalog ->
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
    cond do
      piece_id = Tiqit.scope_piece_id(tiqit) -> "/content/#{piece_id}"
      group_id = Tiqit.scope_group_id(tiqit) -> "/arqade/group/#{group_id}"
      catalog_id = Tiqit.scope_catalog_id(tiqit) -> "/arqade/catalog/#{catalog_id}"
      true -> nil
    end
  end

  defp tiqit_hierarchy(tiqit) do
    cond do
      piece = Tiqit.content_piece(tiqit) ->
        group = piece.content_group
        catalog = group.catalog
        creator = catalog.creator

        [
          content_link(creator.name, arqade_path(:creator, creator)),
          content_link(catalog.name, arqade_path(:catalog, catalog)),
          content_link(group.title, arqade_path(:group, group))
        ]

      group = Tiqit.content_group(tiqit) ->
        catalog = group.catalog
        creator = catalog.creator

        [
          content_link(creator.name, arqade_path(:creator, creator)),
          content_link(catalog.name, arqade_path(:catalog, catalog))
        ]

      catalog = Tiqit.catalog(tiqit) ->
        creator = catalog.creator
        [content_link(creator.name, arqade_path(:creator, creator))]

      true ->
        []
    end
  end

  defp tiqit_content_summary(tiqit) do
    catalog = tiqit_catalog(tiqit)

    cond do
      group_id = Tiqit.scope_group_id(tiqit) ->
        if catalog do
          count = Arcade.count_group_pieces(group_id)
          "#{count} #{Catalog.type_label(catalog.piece_type, count)}"
        end

      catalog_id = Tiqit.scope_catalog_id(tiqit) ->
        if catalog do
          {group_count, piece_count} = Arcade.catalog_content_counts(catalog_id)

          "#{piece_count} #{Catalog.type_label(catalog.piece_type, piece_count)} in #{group_count} #{Catalog.type_label(catalog.group_type, group_count)}"
        end

      true ->
        nil
    end
  end

  defp tiqit_catalog(tiqit), do: Tiqit.catalog(tiqit)
end
