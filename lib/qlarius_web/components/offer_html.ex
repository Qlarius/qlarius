defmodule QlariusWeb.OfferHTML do
  use QlariusWeb, :html

  alias Qlarius.Legacy.Offer

  import QlariusWeb.Money

  @phase_1_amount Decimal.new("0.05")

  attr :phase, :integer, default: 0
  attr :offer, Offer, required: true

  def clickable_offer(assigns) do
    phase_2_amount = Decimal.sub(assigns.offer.offer_amt, @phase_1_amount)
    assigns = assign(assigns, :phase_2_amount, phase_2_amount)

    ~H"""
    <div class="offer-container">
      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-0 #{if @phase > 0, do: "slide-left"}"}>
          <.offer_container offer={@offer} class="p-5 text-neutral-800 bg-white">
            <div class="text-2xl font-bold mb-4">{format_usd(@offer.offer_amt)}</div>
            <div class="mb-4">
              {@offer.media_piece.ad_category.ad_category_name}
            </div>
            <div class="flex justify-between w-full">
              <div class="text-blue-400">
                <.icon name="hero-map-pin" class="w-6 h-6" />
              </div>
              <div class="text-green-600">
                <.icon name="hero-chevron-double-right" class="w-6 h-6" />
              </div>
            </div>
          </.offer_container>
        </div>
      </div>

      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-1 #{if @phase > 1, do: "slide-up"}"}>
          <.offer_container offer={@offer}>
            <div class="flex justify-center items-center">
              <img src={"/images/banner_#{rem(@offer.id, 4)}.png"} alt="Ad image" class="w-full h-auto" />
            </div>
            <.click_jump_actions phase_2_amount={@phase_2_amount} />
          </.offer_container>
        </div>
      </div>

      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-2 #{if @phase > 2, do: "fade-out"}"}>
          <.offer_container offer={@offer} class="px-3 py-2">
            <a class="block w-full h-full" href={~p"/jump/#{@offer}"} target="_blank">
              <div class="text-blue-800 font-bold text-lg underline">
                {@offer.media_piece.title}
              </div>
              <div class="text-gray-700 text-sm mb-1">
                {@offer.media_piece.body_copy}
              </div>
              <div class="text-gray-500 text-xs">
                {@offer.media_piece.display_url}
              </div>
              <.click_jump_actions phase_1_complete? phase_2_amount={@phase_2_amount} />
            </a>
          </.offer_container>
        </div>
      </div>

      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-3 #{if @phase < 3, do: "hidden"}"}>
          <.offer_container
            offer={@offer}
            class="p-3 bg-neutral-100 flex flex-col justify-center text-center text-neutral-600 select-none"
          >
            <div class="text-green-500 -mt-3">
              <.icon name="hero-check" class="w-6 h-6" />
            </div>
            <div class="font-semibold text-sm uppercase text-neutral-400">
              ATTENTION PAID™
            </div>
            <div class="text-sm text-neutral-400">
              Collected: <span class="font-semibold">{format_usd(@offer.offer_amt)}</span>
            </div>
          </.offer_container>
        </div>
      </div>
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
          <.icon name="hero-check" class="text-green-500 w-5 h-5" />
        <% else %>
          <span>TAP FOR </span>
          <span class="font-bold">$0.05</span>
        <% end %>
      </div>
      <div class={[
        "bg-neutral-500 py-2 flex-1 border-l border-neutral-400",
        if(@phase_1_complete?, do: "text-white", else: "text-neutral-400")
      ]}>
        JUMP FOR <span class="font-bold">{format_usd(@phase_2_amount)}</span>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :neutral_bg, :boolean, default: false
  attr :offer, Offer, required: true
  slot :inner_block, required: true

  defp offer_container(assigns) do
    ~H"""
    <div
      phx-click="click-offer"
      phx-value-offer-id={@offer.id}
      class={[
        "relative w-96 h-40 rounded-md border border-neutral-400 overflow-hidden cursor-pointer",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
