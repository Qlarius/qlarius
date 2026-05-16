defmodule QlariusWeb.Components.TiqitPlayer do
  @moduledoc """
  Frame components for playing an unlocked tiqit-backed `ContentPiece`.

  The actual media (currently YouTube) is rendered by
  `QlariusWeb.Components.TiqitUnlockedContent.tiqit_unlocked_content_player/1`.
  This module wraps that core in three context-specific frames so the
  same player can ride in:

    * `:modal`      — fullscreen overlay used for inline Qlink embeds.
    * `:side_panel` — right slide-over inside `Layouts.mobile` (in-app
      arqade); the host passes this through the `:slide_over_content`
      slot.
    * `:page`       — navigates to `/content/:id` (`ContentLive` or
      `ContentController`); the route itself owns the chrome.

  `play_frame_for/1` picks the right frame from socket assigns. The
  global `:tiqit_player_frame` application env (default `:auto`) can
  pin every surface to a single frame for kill-switch / debugging.
  """
  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1]
  import QlariusWeb.Components.TiqitUnlockedContent, only: [tiqit_unlocked_content_player: 1]

  alias Qlarius.Tiqit.Arcade.ContentPiece

  @type play_frame :: :modal | :side_panel | :page

  @doc """
  Returns the frame the player should render in, given the host
  LiveView's assigns.

  The decision is `assigns`-driven (not UA / PWA): if the page is
  inside `Layouts.mobile` (in-app routed arqade), use the side panel;
  if it's a nested inline embed under a Qlink page, use the modal;
  otherwise (standalone widget) navigate to the page.

  An optional global override pinned via
  `Application.put_env(:qlarius, :tiqit_player_frame, :page | :modal | :side_panel)`
  forces every surface to that frame.
  """
  @spec play_frame_for(map()) :: play_frame
  def play_frame_for(assigns) when is_map(assigns) do
    case Application.get_env(:qlarius, :tiqit_player_frame, :auto) do
      :modal -> :modal
      :side_panel -> :side_panel
      :page -> :page
      _ -> auto_frame_for(assigns)
    end
  end

  defp auto_frame_for(%{inline?: true}), do: :modal
  defp auto_frame_for(%{base_path: "/widgets"}), do: :page
  defp auto_frame_for(_), do: :side_panel

  attr :id, :string, required: true, doc: "DOM-id prefix; piece id is appended for uniqueness."
  attr :piece, ContentPiece, required: true
  attr :group, :map, required: true
  attr :tiqit, :map, required: true
  attr :leaving?, :boolean, default: false, doc: "Set true during the close animation."

  attr :force_theme, :string,
    default: nil,
    doc: "Theme to apply via `data-theme` (widget embeds only)."

  attr :target, :string,
    default: nil,
    doc: "phx-target selector for close events (e.g. \"#abc123\" for inline embed routing)."

  attr :close_event, :string,
    default: "close-tiqit-content",
    doc: "Event name pushed by Escape / X."

  attr :id_prefix, :string,
    default: "tiqit-modal",
    doc: "Prefix used when generating the inner player's DOM ids."

  @doc """
  Fullscreen modal frame — fixed overlay, body scroll lock, Escape to
  close. Used for inline Qlink embeds where the host page already
  owns layout chrome and navigating away would unmount the embed.

  Close animation is driven by `:leaving?` plus the
  `.tiqit-content-modal-leaving` / `-active` classes in `app.css`.
  Owning LV is responsible for the timer that flips `:leaving?` →
  `show_*: false` after the animation.
  """
  def player_modal_frame(assigns) do
    ~H"""
    <div
      id={"#{@id}-#{@piece.id}"}
      phx-hook="BodyScrollLock"
      data-body-scroll-lock="true"
      class={[
        "fixed inset-0 z-[110] flex flex-col bg-base-100",
        "tiqit-content-modal-active",
        @leaving? && "tiqit-content-modal-leaving"
      ]}
      data-theme={@force_theme}
      phx-window-keydown={@close_event}
      phx-key="Escape"
      phx-target={@target}
    >
      <div class="flex items-center justify-between gap-2 p-3 pt-[max(0.75rem,env(safe-area-inset-top))] border-b border-base-300 bg-base-100 flex-shrink-0">
        <span class="font-semibold text-base-content truncate">{@piece.title}</span>
        <button
          type="button"
          phx-click={@close_event}
          phx-target={@target}
          class="btn btn-ghost btn-circle flex-shrink-0"
          aria-label="close"
        >
          <.icon name="hero-x-mark" class="w-6 h-6" />
        </button>
      </div>
      <div class="flex-1 min-h-0 overflow-y-auto p-4 pb-8 max-w-4xl w-full mx-auto">
        <.tiqit_unlocked_content_player
          id_prefix={"#{@id_prefix}-#{@piece.id}"}
          piece={@piece}
          group={@group}
          tiqit={@tiqit}
        />
      </div>
    </div>
    """
  end

  attr :piece, ContentPiece, required: true
  attr :group, :map, required: true
  attr :tiqit, :map, required: true

  attr :id_prefix, :string,
    default: "tiqit-side-panel",
    doc: "Prefix used when generating the inner player's DOM ids."

  @doc """
  Side-panel frame — thin wrapper around the core player meant to live
  inside `Layouts.mobile`'s `:slide_over_content` slot. The slide-over
  already provides its own back button (`phx-click=\"close_slide_over\"`)
  back button; the host LV sets `slide_over_active` when opening. Leave
  `slide_over_title` blank — the core player renders the piece title.
  """
  def player_side_panel_frame(assigns) do
    ~H"""
    <%!-- Same cap as modal / content page; slide-over panel supplies horizontal padding. --%>
    <div class="w-full max-w-4xl mx-auto pb-4">
      <.tiqit_unlocked_content_player
        id_prefix={"#{@id_prefix}-#{@piece.id}"}
        piece={@piece}
        group={@group}
        tiqit={@tiqit}
      />
    </div>
    """
  end
end
