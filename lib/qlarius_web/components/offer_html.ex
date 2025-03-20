defmodule QlariusWeb.OfferHTML do
  use QlariusWeb, :html

  alias Qlarius.Offer

  import QlariusWeb.Money

  attr :phase, :integer, default: 0
  attr :offer, Offer, required: true

  def clickable_offer(assigns) do
    case assigns.phase do
      0 ->
        ~H"""
        <.offer_container offer={@offer} class="p-5 text-neutral-800">
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
        """

      1 ->
        ~H"""
        <.offer_container offer={@offer}>
          <div class="flex justify-center items-center">
            <img src={"/images/banner_#{rem(@offer.id, 4)}.png"} alt="Ad image" class="w-full h-auto" />
          </div>
          <.click_jump_actions phase_2_amount={@offer.phase_2_amount} />
        </.offer_container>
        """

      2 ->
        ~H"""
        <.offer_container offer={@offer} class="px-3 py-2">
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
            <div class="text-gray-500 text-xs">
              {@offer.media_piece.display_url}
            </div>
            <.click_jump_actions phase_1_complete? phase_2_amount={@offer.phase_2_amount} />
          </a>
        </.offer_container>
        """

      3 ->
        ~H"""
        <.offer_container
          offer={@offer}
          class="p-3 bg-neutral-100 flex flex-col justify-center text-center text-neutral-600 select-none"
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
        """
    end
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
