defmodule QlariusWeb.Components.PWAInstallPrompt do
  @moduledoc """
  PWA install prompt styled after Safari's Smart App Banner and the App Store
  product sheet.

  `install_banner/1` is the top banner with an Install pill. Install opens
  `install_sheet/1` as a bottom sheet (`ios_install_guide/1` /
  `android_install_guide/1`); `/hi` renders the same sheet as a page.
  """
  use Phoenix.Component
  import QlariusWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @app_icon "/images/qadabra_app_icon_192.png"
  @banner_subtitle "New: lighter, faster, private install"
  @sheet_subtitle "Your attention. Your wallet. Your app."

  @info_cells [
    %{label: "Size", icon: "hero-photo", value: "Smaller than a photo"},
    %{label: "Tracking", icon: "hero-eye-slash", value: "None"},
    %{label: "Updates", icon: "hero-arrow-path", value: "Automatic"},
    %{label: "Store", icon: "hero-building-storefront", value: "Not needed"}
  ]

  @benefits [
    %{
      icon: "hero-cube-transparent",
      tile: "bg-[#34c759]",
      title: "Lighter footprint",
      body: "Smaller than a single photo, with nothing extra to download."
    },
    %{
      icon: "hero-bolt",
      tile: "bg-[#ff9500]",
      title: "Always current",
      body: "Updates arrive the moment we ship them, with no store review and no update button."
    },
    %{
      icon: "hero-lock-closed",
      tile: "bg-[#007aff]",
      title: "Privacy-first",
      body:
        "Runs in your browser's sandbox, with no advertising ID and no tracking SDKs. " <>
          "Qadabra sees only what you choose to share."
    },
    %{
      icon: "hero-device-phone-mobile",
      tile: "bg-[#5856d6]",
      title: "Feels native",
      body: "Full screen, on your Home Screen, with notifications when new offers arrive."
    },
    %{
      icon: "hero-user-minus",
      tile: "bg-[#8e8e93]",
      title: "No account needed",
      body: "No App Store or Google Play sign-in."
    }
  ]

  @ios_steps [
    %{
      glyph: "hero-ellipsis-horizontal",
      title: "Tap ••• (More)",
      hint: "The round button at the bottom right of Safari, next to the address bar."
    },
    %{
      glyph: "hero-arrow-up-on-square",
      title: "Tap Share",
      hint: "It's the first item in the menu. The share sheet opens with Qadabra at the top.",
      preview: :share_header
    },
    %{
      glyph: "hero-chevron-down",
      title: "Tap View More",
      hint: "The round arrow at the end of the Copy, Add to Bookmarks, Add to Reading List row."
    },
    %{
      glyph: :add_square,
      title: "Tap Add to Home Screen",
      hint: "In the list that opens, below Find on Page.",
      preview: :add_to_home_screen
    },
    %{
      glyph: "hero-plus",
      title: "Tap Add",
      hint: "Leave Open as Web App on.",
      preview: :add_pill
    }
  ]

  @android_steps [
    %{
      glyph: "hero-ellipsis-vertical",
      title: "Tap the menu (⋮)",
      hint: "Usually at the top right of Chrome."
    },
    %{
      glyph: "hero-arrow-down-tray",
      title: "Tap Install app",
      hint: "Some browsers say Add to Home screen.",
      preview: :install_app
    },
    %{
      glyph: "hero-plus",
      title: "Tap Install",
      hint: "Qadabra appears on your Home Screen and in your app drawer."
    }
  ]

  attr :show_banner, :boolean, default: false
  attr :is_ios, :boolean, default: false
  attr :is_android, :boolean, default: false

  def install_banner(assigns) do
    assigns =
      assigns
      |> assign(:app_icon, @app_icon)
      |> assign(:subtitle, @banner_subtitle)

    ~H"""
    <div
      :if={@show_banner}
      id="pwa-install-banner"
      class="smart-banner"
      role="region"
      aria-label="Install Qadabra"
      phx-remove={
        JS.transition({"smart-banner--animating", "smart-banner--open", "smart-banner--collapsed"},
          time: 300
        )
      }
    >
      <div class="smart-banner__clip">
        <div class="smart-banner__row">
          <button
            type="button"
            phx-click="dismiss_install_banner"
            class="smart-banner__close"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
          <img src={@app_icon} alt="" class="app-icon h-14 w-14" />
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-[15px] font-semibold">Qadabra</p>
            <p class="ios-secondary text-[13px]">{@subtitle}</p>
          </div>
          <button
            :if={@is_ios}
            type="button"
            phx-click="show_ios_guide"
            class="ios-pill"
          >
            Install
          </button>
          <button
            :if={@is_android}
            id="android-install-button"
            type="button"
            phx-click="show_android_guide"
            class="ios-pill"
          >
            Install
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :show, :boolean, required: true

  def ios_install_guide(assigns) do
    ~H"""
    <.install_sheet :if={@show} platform={:ios} variant={:modal} />
    """
  end

  attr :show, :boolean, required: true

  def android_install_guide(assigns) do
    ~H"""
    <.install_sheet :if={@show} platform={:android} variant={:modal} />
    """
  end

  @doc """
  App Store-style listing with info strip, What's New, benefits, and the
  platform's install steps. `:modal` renders a dismissible bottom sheet;
  `:page` renders inline (the `/hi` install mode), with `:footer` for
  page-level actions.
  """
  attr :platform, :atom, values: [:ios, :android], required: true
  attr :variant, :atom, values: [:modal, :page], default: :modal
  slot :footer

  def install_sheet(%{variant: :modal} = assigns) do
    assigns = assign(assigns, :hide_event, hide_event(assigns.platform))

    ~H"""
    <div class="modal modal-bottom md:modal-middle modal-open" phx-click={@hide_event}>
      <div
        class="app-sheet w-full max-w-lg justify-self-center max-h-[92dvh] overflow-y-auto rounded-t-[1.25rem] md:rounded-[1.25rem] pb-[env(safe-area-inset-bottom)] md:pb-0 shadow-2xl"
        phx-click="stop_propagation"
      >
        <div class="app-sheet__grabber md:hidden" aria-hidden="true" />
        <div class="flex justify-end px-4 pt-2">
          <button
            type="button"
            phx-click={@hide_event}
            class="app-sheet__close"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>
        <.sheet_body platform={@platform} id_prefix="install-sheet" />
      </div>
    </div>
    """
  end

  def install_sheet(%{variant: :page} = assigns) do
    ~H"""
    <div class="app-sheet w-full max-w-lg mx-auto rounded-[1.25rem] pt-4 shadow-xl">
      <.sheet_body platform={@platform} id_prefix="install-page" />
      <div :if={@footer != []} class="px-4 pb-6 text-center">{render_slot(@footer)}</div>
    </div>
    """
  end

  @doc """
  App Store listing header: icon, name, subtitle, and an action slot for the
  Install pill.
  """
  attr :subtitle, :string, default: @sheet_subtitle
  slot :action, required: true
  slot :inner_block

  def listing_header(assigns) do
    assigns = assign(assigns, :app_icon, @app_icon)

    ~H"""
    <div class="flex items-center gap-4 text-left">
      <img src={@app_icon} alt="" class="app-icon h-24 w-24" />
      <div class="min-w-0 flex-1">
        <h2 class="text-[22px] leading-tight font-bold">Qadabra</h2>
        <p class="ios-secondary text-[15px] leading-snug">{@subtitle}</p>
        <div class="mt-3 flex flex-wrap items-center gap-3">{render_slot(@action)}</div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :platform, :atom, required: true
  attr :id_prefix, :string, required: true

  defp sheet_body(assigns) do
    assigns =
      assigns
      |> assign(:steps_id, "#{assigns.id_prefix}-steps")
      |> assign(:info_cells, @info_cells)
      |> assign(:benefits, @benefits)
      |> assign(:steps, steps(assigns.platform))

    ~H"""
    <div class="space-y-6 pb-6">
      <div class="px-4">
        <.listing_header>
          <:action>
            <button
              id={@platform == :android && "trigger-android-install"}
              type="button"
              phx-click={JS.dispatch("qlarius:scroll-into-view", to: "##{@steps_id}")}
              class="ios-pill ios-pill--lg"
            >
              Install
            </button>
          </:action>
          <p :if={@platform == :android} class="ios-secondary mt-2 text-[13px]">
            Your browser will ask to confirm. Tap Install.
          </p>
        </.listing_header>
      </div>

      <div class="app-sheet__info">
        <div :for={cell <- @info_cells} class="app-sheet__info-cell">
          <span class="app-sheet__info-label">{cell.label}</span>
          <.icon name={cell.icon} class="ios-secondary h-6 w-6" />
          <span class="text-[13px] leading-tight font-medium">{cell.value}</span>
        </div>
      </div>

      <section class="space-y-2 px-4">
        <h3 class="app-sheet__heading">What's New</h3>
        <div class="app-sheet__group px-4 py-3">
          <p class="text-[17px] font-semibold">A new way to install</p>
          <p class="ios-secondary mt-1 text-[15px] leading-snug">
            Qadabra installs straight from your browser, with no app store in the middle. It's smaller than a photo, opens instantly from your Home Screen, and updates itself without app store hold ups.
          </p>
        </div>
      </section>

      <section class="space-y-2 px-4">
        <h3 class="app-sheet__heading">Why install this way</h3>
        <div class="app-sheet__group">
          <div :for={benefit <- @benefits} class="app-sheet__row">
            <span class={["app-sheet__tile", benefit.tile]} aria-hidden="true">
              <.icon name={benefit.icon} class="h-[18px] w-[18px]" />
            </span>
            <div class="app-sheet__row-body">
              <p class="text-[15px] font-semibold">{benefit.title}</p>
              <p class="ios-secondary text-[13px] leading-snug">{benefit.body}</p>
            </div>
          </div>
        </div>
      </section>

      <section id={@steps_id} class="scroll-mt-4 space-y-2 px-4">
        <h3 class="app-sheet__heading">How to install</h3>
        <ol class="app-sheet__group">
          <li :for={{step, index} <- Enum.with_index(@steps, 1)} class="app-sheet__row">
            <span class="app-sheet__glyph" aria-hidden="true">
              <.step_glyph glyph={step.glyph} />
            </span>
            <div class="app-sheet__row-body">
              <p class="text-[15px] font-semibold">{index}. {step.title}</p>
              <p class="ios-secondary text-[13px] leading-snug">{step.hint}</p>
              <.step_preview :if={step[:preview]} preview={step.preview} />
            </div>
          </li>
        </ol>
        <p :if={@platform == :ios} class="ios-secondary px-1 text-[13px] leading-snug">
          On older iPhones the Share button is in the toolbar; tap it and skip to step 3.
        </p>
      </section>

      <p class="ios-secondary px-4 text-center text-[13px]">Uninstall anytime, like any app.</p>
    </div>
    """
  end

  attr :glyph, :any, required: true

  defp step_glyph(%{glyph: :add_square} = assigns) do
    ~H"""
    <.add_square_svg class="h-5 w-5" />
    """
  end

  defp step_glyph(assigns) do
    ~H"""
    <.icon name={@glyph} class="h-5 w-5" />
    """
  end

  attr :preview, :atom, required: true

  defp step_preview(%{preview: :share_header} = assigns) do
    assigns = assign(assigns, :app_icon, @app_icon)

    ~H"""
    <div class="app-sheet__preview" aria-hidden="true">
      <img src={@app_icon} alt="" class="app-icon h-9 w-9" />
      <span class="leading-tight">
        <span class="block text-[14px] font-semibold">Qadabra</span>
        <span class="ios-secondary block text-[12px]">qadabra.app</span>
      </span>
    </div>
    """
  end

  defp step_preview(%{preview: :add_to_home_screen} = assigns) do
    ~H"""
    <div class="app-sheet__preview" aria-hidden="true">
      <.add_square_svg class="h-5 w-5" />
      <span>Add to Home Screen</span>
    </div>
    """
  end

  defp step_preview(%{preview: :add_pill} = assigns) do
    ~H"""
    <div class="app-sheet__preview font-semibold" aria-hidden="true">Add</div>
    """
  end

  defp step_preview(%{preview: :install_app} = assigns) do
    ~H"""
    <div class="app-sheet__preview" aria-hidden="true">
      <.icon name="hero-arrow-down-tray" class="h-5 w-5" />
      <span>Install app</span>
    </div>
    """
  end

  attr :class, :string, default: nil

  defp add_square_svg(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="3" y="3" width="18" height="18" rx="4" stroke="currentColor" stroke-width="1.75" />
      <path d="M12 8v8M8 12h8" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" />
    </svg>
    """
  end

  defp steps(:ios), do: @ios_steps
  defp steps(:android), do: @android_steps

  defp hide_event(:ios), do: "hide_ios_guide"
  defp hide_event(:android), do: "hide_android_guide"
end
