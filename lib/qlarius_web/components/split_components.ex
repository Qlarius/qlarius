defmodule QlariusWeb.Components.SplitComponents do
  use Phoenix.Component
  import QlariusWeb.CoreComponents
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.InstaTipComponents, only: [insta_tip_button_group: 1]

  @doc """
  Split tab trigger button showing current split percentage.
  """
  attr :split_amount, :integer, required: true
  attr :class, :string, default: nil

  def split_tab(assigns) do
    ~H"""
    <button
      phx-click="toggle_split_drawer"
      class={[
        "flex items-center gap-2 bg-gray-700 text-white px-5 py-2 rounded-tl-3xl cursor-pointer select-none hover:bg-gray-600 transition-colors",
        @class
      ]}
    >
      <span class="uppercase text-xs tracking-wider font-semibold">
        SPLIT: {@split_amount}%
      </span>
      <svg
        class="w-5 h-5"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
        />
        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    </button>
    """
  end

  @doc """
  AutoSplit percentage selector buttons.
  """
  attr :split_amount, :integer, required: true
  # See docs/embedded_theming.md for force_light/pub_theme strategy
  attr :force_light, :boolean, default: false

  def auto_split_controls(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <div class="text-lg font-bold text-base-content mb-1">AutoSplit</div>
      <div class="text-base-content/70 text-sm mb-4 text-center">
        Automatically tip a percentage from each ad engaged on this site.
      </div>
      <div class="inline-flex rounded-lg overflow-hidden border border-base-300 bg-base-100 divide-x divide-base-300">
        <%= for percentage <- [0, 25, 50, 75, 100] do %>
          <button
            type="button"
            phx-click="set_split"
            phx-value-split={to_string(percentage)}
            class={[
              "px-4 py-2 text-sm font-medium transition-colors cursor-pointer",
              if(@split_amount == percentage,
                do: "bg-primary text-primary-content",
                else: "bg-base-100 text-base-content hover:bg-base-200"
              )
            ]}
          >
            {percentage}%
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Disclaimer bar for ad drawer.
  """
  attr :class, :string, default: nil

  def ads_disclaimer_bar(assigns) do
    ~H"""
    <div class={[
      "bg-gray-500 text-white text-xs text-center py-4 px-4",
      @class
    ]}>
      These ads are matched directly to your MeFile and are in no way linked to any site you visit or content you consume.
    </div>
    """
  end

  @doc """
  Full tip/split drawer content with InstaTip, AutoSplit, and Recipient sections.
  """
  attr :recipient, :map, required: true
  attr :wallet_balance, :any, required: true
  attr :split_amount, :integer, required: true
  attr :show, :boolean, default: false
  # See docs/embedded_theming.md for force_light/pub_theme strategy
  attr :force_light, :boolean, default: false

  def tip_split_drawer(assigns) do
    ~H"""
    <div
      class={[
        "absolute inset-x-0 bottom-0 bg-base-200 transition-transform duration-300 ease-out z-30",
        if(@show, do: "translate-y-0", else: "translate-y-full")
      ]}
      style="max-height: 90%;"
    >
      <%!-- Header --%>
      <div class="w-full bg-base-100 border-b border-base-300 p-5 flex justify-between items-center shadow-sm">
        <div class="text-base-content font-bold uppercase tracking-wider text-sm">
          TIP TO SUPPORT WHAT MATTERS
        </div>
        <button
          phx-click="toggle_split_drawer"
          class="flex items-center justify-center w-10 h-10 rounded-full border border-base-300 bg-base-100 shadow hover:bg-base-200 cursor-pointer transition-colors"
        >
          <.icon name="hero-chevron-down" class="w-6 h-6 text-base-content" />
        </button>
      </div>

      <%!-- Content --%>
      <div class="flex flex-col md:flex-row gap-8 px-8 pt-6 pb-8 overflow-y-auto max-w-[800px] mx-auto">
        <%!-- Left: InstaTip + AutoSplit --%>
        <div class="flex-1 flex flex-col items-center md:items-start">
          <%!-- InstaTip Section --%>
          <div class="text-lg font-bold text-base-content mb-1">InstaTip</div>
          <div class="text-base-content/70 text-sm mb-4">
            Instantly tip from your wallet
            <.icon name="hero-arrow-right" class="w-4 h-4 inline-block" />
            <span class="inline-flex items-center text-lg bg-sponster-200 text-base-content px-3 py-1 rounded-lg border border-sponster-300">
              <span class="font-bold">{format_usd(@wallet_balance)}</span>
            </span>
          </div>
          <.insta_tip_button_group
            amounts={["0.25", "0.50", "1.00", "2.00"]}
            wallet_balance={@wallet_balance}
            recipient_id={@recipient && @recipient.id}
          />

          <div class="divider my-6"></div>

          <%!-- AutoSplit Section --%>
          <.auto_split_controls split_amount={@split_amount} force_light={@force_light} />
        </div>

        <%!-- Right: Recipient --%>
        <div class="flex-1 flex flex-col items-center border-t border-base-300 pt-6 md:pt-0 md:border-none">
          <%= if @recipient do %>
            <div class="text-2xl font-bold text-base-content mb-2 text-center">
              {@recipient.name || "Recipient"}
            </div>
            <div class="flex flex-col items-center gap-4">
              <div class="w-40 h-auto bg-base-300 shadow-md flex items-center justify-center overflow-hidden rounded">
                <img
                  src={
                    if @recipient.graphic_url do
                      QlariusWeb.Uploaders.RecipientBrandImage.url({@recipient.graphic_url, @recipient})
                    else
                      "/images/tipjar_love_default.png"
                    end
                  }
                  alt={@recipient.name || "Recipient"}
                  class="object-contain w-full h-full"
                />
              </div>
              <div class="text-base-content/70 text-sm text-center max-w-xs">
                {@recipient.message ||
                  "Thank you for supporting this content. Your Sponster tips are greatly appreciated!"}
              </div>
            </div>
          <% else %>
            <div class="text-base-content/50 text-center py-8">
              No recipient configured for this page
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
