defmodule QlariusWeb.OfferHTML do
  use QlariusWeb, :html

  alias Qlarius.Sponster.Offer

  import QlariusWeb.Money

  @phase_1_amount Decimal.new("0.05")

  attr :phase, :integer, default: 0
  attr :target, :any
  attr :offer, Offer, required: true

  def clickable_offer(assigns) do
    phase_2_amount = Decimal.sub(assigns.offer.amount, @phase_1_amount)
    assigns = assign(assigns, :phase_2_amount, phase_2_amount)

    ~H"""
    <div class="relative w-96 h-40 mb-4 overflow-hidden">
      <.offer_container
        offer={@offer}
        class={"p-5 text-neutral-800 phase-0 bg-white #{if @phase > 0, do: "slide-left"}"}
        target={@target}
      >
        <div class="text-2xl font-bold mb-4">{format_usd(@offer.amount)}</div>
        <div class="mb-4">
          {@offer.ad_category.name}
        </div>
        <div class="flex justify-between w-full">
          <div class="text-blue-400">
            <.icon name="hero-map-pin" class="w-6 h-6" />
          </div>
          <div class="text-green-600">
            <.icon name="hero-forward" class="w-6 h-6" />
          </div>
        </div>
      </.offer_container>

      <.offer_container
        offer={@offer}
        class={"phase-1 #{if @phase > 1, do: "slide-up"}"}
        target={@target}
      >
        <div class="flex justify-center items-center bg-white">
          <%= if @offer.media_piece.banner_image do %>
            <img
              src={
                QlariusWeb.Uploaders.ThreeTapBanner.url(
                  {@offer.media_piece.banner_image, @offer.media_piece},
                  :original
                )
              }
              alt="Ad image"
              class="w-full h-auto"
            />
          <% else %>
            <div class="w-full h-40 bg-gray-200 flex items-center justify-center">
              <span class="text-gray-400">No banner</span>
            </div>
          <% end %>
        </div>
        <.click_jump_actions phase_2_amount={@phase_2_amount} />
      </.offer_container>

      <.offer_container
        offer={@offer}
        class={"px-3 py-2 phase-2 #{if @phase > 2, do: "hidden"}"}
        target={@target}
      >
        <%!-- clicking this link opens the 'jump' link in a new tab, and also
          triggers the phx-click="click-offer" handler on the wrapping
          <.offer_container> --%>
        <a class="block w-full h-full" href={~p"/jump/#{@offer}"} target="_blank">
          <div class="text-blue-800 font-bold text-lg mb-1 underline">
            {@offer.media_piece.title}
          </div>
          <div class="text-gray-700 text-sm mb-1">
            {@offer.media_piece.body_copy}
          </div>
          <div class="text-green-500 text-xs">
            {@offer.media_piece.display_url}
          </div>
          <.click_jump_actions phase_1_complete? phase_2_amount={@phase_2_amount} />
        </a>
      </.offer_container>

      <.offer_container
        offer={@offer}
        class={"p-3 bg-neutral-100 flex flex-col justify-center text-center text-neutral-600 select-none phase-3 #{if @phase < 3, do: "hidden"}"}
        target={@target}
      >
        <div class="text-green-500 mb-1">
          <.icon name="hero-check" class="w-6 h-6" />
        </div>
        <div class="font-semibold text-sm tracking-wide uppercase mb-2">
          ATTENTION PAID™
        </div>
        <div class="text-sm">
          Collected: <span class="font-semibold">{format_usd(@offer.amount)}</span>
        </div>
      </.offer_container>
    </div>
    """
  end

  attr :phase_1_complete?, :boolean, default: false
  attr :phase_2_amount, Decimal, required: true

  def click_jump_actions(assigns) do
    ~H"""
    <div class="flex text-white text-center text-xs font-light absolute bottom-0 left-0 w-full">
      <div class={[
        "py-2 flex-1",
        (@phase_1_complete? && "bg-neutral-200") || "bg-neutral-600"
      ]}>
        <%= if @phase_1_complete? do %>
          <.icon name="hero-check" class="text-green-500 w-4 h-4" />
        <% else %>
          <span>CLICK FOR </span>
          <span class="font-bold">$0.05</span>
        <% end %>
      </div>
      <div class="bg-neutral-500 py-2 flex-1 border-l border-neutral-400">
        <span>CLICK/JUMP FOR </span>
        <span class="font-bold">{format_usd(@phase_2_amount)}</span>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :neutral_bg, :boolean, default: false
  attr :offer, Offer, required: true
  attr :target, :any

  slot :inner_block, required: true

  defp offer_container(assigns) do
    ~H"""
    <div
      phx-click="click-offer"
      phx-target={@target}
      phx-value-offer-id={@offer.id}
      class={[
        "absolute top-0 left-0 w-full h-full transition-transform duration-300 ease-in-out rounded-md border border-neutral-400 overflow-hidden cursor-pointer",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
