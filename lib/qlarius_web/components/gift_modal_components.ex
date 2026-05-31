defmodule QlariusWeb.Components.GiftModalComponents do
  @moduledoc """
  Shared shell, typography, and controls for gift/share invitation modals.

  Visual language matches `QlariusWeb.Components.AuthSheet` (widget borders,
  spacing, button sizes, and type scale).
  """
  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1, modal: 1]

  @primary_btn_classes "btn-widget btn-widget-emphasis btn-lg btn-block min-h-14 rounded-full py-3.5 text-base whitespace-nowrap"
  @ghost_btn_classes "btn-widget-ghost btn-md min-h-11 rounded-full text-sm"
  @modal_border_class "border border-widget-300"
  @tiqit_arqade_modal_border_class "border border-widget-700"
  @modal_backdrop_class "bg-base-300/80 backdrop-blur-sm"
  @modal_panel_radius_class "rounded-box"
  @modal_sheet_panel_radius_class "rounded-t-box md:rounded-box"
  @modal_body_padding "p-6 md:p-8"
  @modal_content_stack "space-y-5"

  attr :id, :string, default: "gift-invitation-modal"
  attr :on_dismiss, :any, required: true
  slot :inner_block, required: true
  slot :footnote

  def overlay(assigns) do
    assigns =
      assigns
      |> assign(:modal_body_padding, @modal_body_padding)
      |> assign(:tiqit_arqade_modal_border_class, @tiqit_arqade_modal_border_class)

    ~H"""
    <.modal
      id={@id}
      show
      border_class={@tiqit_arqade_modal_border_class}
      on_cancel={@on_dismiss}
    >
      <div class={"mx-auto w-full max-w-lg overflow-y-auto #{@modal_body_padding}"}>
        {render_slot(@inner_block)}
        <%= if @footnote != [] do %>
          <div class="mt-5 border-t border-base-content/[0.07] pt-4">
            {render_slot(@footnote)}
          </div>
        <% end %>
      </div>
    </.modal>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def body(assigns) do
    assigns =
      assigns
      |> assign(:modal_body_padding, @modal_body_padding)
      |> assign(:modal_content_stack, @modal_content_stack)

    ~H"""
    <div class={[@modal_body_padding, @class]}>
      <div class={@modal_content_stack}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def content_stack(assigns) do
    ~H"""
    <div class={["w-full space-y-5 text-center", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def header_block(assigns) do
    ~H"""
    <div class={["flex flex-col items-center gap-0 text-center", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def lede_group(assigns) do
    ~H"""
    <div class={["w-full space-y-2", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def actions_group(assigns) do
    ~H"""
    <div class={["flex w-full flex-col gap-3", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :src, :string, default: "/images/Tiqit_logo_color_horiz.svg"
  attr :alt, :string, default: "Tiqit"
  attr :class, :string, default: "h-9 w-auto max-w-[min(18rem,88vw)] object-contain md:h-11"

  def brand_logo(assigns) do
    ~H"""
    <div class="flex justify-center">
      <img src={@src} alt={@alt} class={@class} decoding="async" />
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :icon_class, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def icon_title(assigns) do
    ~H"""
    <h2 class={[
      "flex items-center justify-center gap-2 text-2xl font-bold text-widget-900 md:text-3xl dark:text-white",
      @class
    ]}>
      <.icon
        name={@icon}
        class={@icon_class || "h-8 w-8 shrink-0 text-current md:h-9 md:w-9"}
      />
      <span>{render_slot(@inner_block)}</span>
    </h2>
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  def title(assigns) do
    ~H"""
    <h2 class="text-center text-2xl font-bold text-widget-900 md:text-3xl dark:text-white" {@rest}>
      {render_slot(@inner_block)}
    </h2>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def lede(assigns) do
    ~H"""
    <p class={["text-center text-sm text-base-content/70 md:text-base", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def emphasis_lede(assigns) do
    ~H"""
    <p class={["text-center text-sm font-medium text-warning md:text-base", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def footnote(assigns) do
    ~H"""
    <p class={["text-center text-xs text-base-content/60", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :icon, :string, required: true
  attr :class, :string, default: nil

  def header_icon(assigns) do
    ~H"""
    <.icon
      name={@icon}
      class={@class || "mx-auto mb-3 h-10 w-10 text-widget-700 md:mb-4 dark:text-widget-300"}
    />
    """
  end

  attr :image_url, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :includes, :string, default: nil
  attr :duration, :string, default: nil
  attr :class, :string, default: ""

  def content_shelf(assigns) do
    ~H"""
    <div class={[
      "mx-auto w-full max-w-[400px] rounded-xl border border-widget-300 bg-widget-100/60 p-3",
      "dark:border-widget-700/40 dark:bg-widget-900/25",
      @class
    ]}>
      <div class="flex flex-row items-start gap-4">
        <div class="relative shrink-0">
          <img
            src={@image_url}
            alt={@title}
            class="block h-auto max-h-32 w-24 object-contain rounded-lg"
          />
        </div>
        <div class="min-w-0 flex-1 space-y-1 text-left">
          <p :if={@subtitle} class="text-sm leading-snug text-base-content/60">
            {@subtitle}
          </p>
          <h3 class="text-base font-bold leading-snug text-widget-900 [overflow-wrap:anywhere] dark:text-white">
            {@title}
          </h3>
          <p :if={@includes} class="text-sm text-base-content/70">
            {@includes}
          </p>
          <p :if={@duration} class="text-xs text-base-content/50">
            {@duration}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :name, :string, default: "pin"
  attr :rest, :global

  def pin_input(assigns) do
    ~H"""
    <input
      type="text"
      name={@name}
      inputmode="numeric"
      pattern="[0-9]*"
      maxlength="4"
      autocomplete="off"
      autocorrect="off"
      autocapitalize="off"
      spellcheck="false"
      data-form-type="other"
      data-1p-ignore="true"
      data-lpignore="true"
      data-bwignore="true"
      placeholder="1234"
      class="input input-bordered w-full border-widget-300 text-center text-xl font-medium tracking-[0.5em] focus:border-widget-700 focus:outline-none focus:ring-2 focus:ring-widget-200 md:text-2xl"
      {@rest}
    />
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def primary_button(assigns) do
    assigns = assign(assigns, :primary_btn_classes, @primary_btn_classes)

    ~H"""
    <button type="button" class={[@primary_btn_classes, @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ghost_button(assigns) do
    assigns = assign(assigns, :ghost_btn_classes, @ghost_btn_classes)

    ~H"""
    <button type="button" class={[@ghost_btn_classes, @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def submit_button(assigns) do
    assigns = assign(assigns, :primary_btn_classes, @primary_btn_classes)

    ~H"""
    <button type="submit" class={[@primary_btn_classes, @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :value, :string, required: true
  attr :rows, :integer, default: 9
  attr :class, :string, default: ""

  def invitation_textarea(assigns) do
    ~H"""
    <textarea
      id={@id}
      readonly
      rows={@rows}
      class={[
        "textarea textarea-bordered tiqit-invitation-text w-full min-h-[12rem] resize-y",
        "border-widget-300 bg-base-100 py-4 px-4 text-left text-sm leading-relaxed",
        "focus:border-widget-700 focus:outline-none focus:ring-2 focus:ring-widget-200",
        @class
      ]}
    >{@value}</textarea>
    """
  end

  @doc false
  def modal_border_class, do: @modal_border_class

  @doc false
  def tiqit_arqade_modal_border_class, do: @tiqit_arqade_modal_border_class

  @doc false
  def modal_backdrop_class, do: @modal_backdrop_class

  @doc false
  def modal_panel_radius_class, do: @modal_panel_radius_class

  @doc false
  def modal_sheet_panel_radius_class, do: @modal_sheet_panel_radius_class

  @doc false
  def modal_body_padding, do: @modal_body_padding

  @doc false
  def modal_content_stack, do: @modal_content_stack

  @doc false
  def primary_button_classes, do: @primary_btn_classes

  @doc false
  def ghost_button_classes, do: @ghost_btn_classes
end
