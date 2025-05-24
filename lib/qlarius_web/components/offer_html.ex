defmodule QlariusWeb.OfferHTML do
  use QlariusWeb, :html

  alias Qlarius.Sponster.{Offer, Recipient}
  alias Qlarius.YouData.MeFiles.MeFile
  alias QlariusWeb.ThreeTapBanner
  alias Qlarius.Sponster.Ads.ThreeTap
  import Ecto.Query, except: [update: 2, update: 3]

  import QlariusWeb.Money

  @phase_1_amount Decimal.new("0.05")

  attr :phase, :integer, default: 0
  attr :offer, Offer, required: true
  attr :recipient, :any, default: nil
  attr :me_file, MeFile, required: true
  attr :split_amount, :integer, default: 0

  def clickable_offer(assigns) do
    # recipient = assigns.r`ecipient
    split_amount = assigns.me_file.split_amount
    phase_2_amount = Decimal.sub(assigns.offer.offer_amt, @phase_1_amount)
    assigns = assign(assigns, :phase_2_amount, phase_2_amount)
    assigns = assign_new(assigns, :target, fn -> nil end)

    ~H"""
    <div class="offer-container">

      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-0 #{if @phase > 0, do: "slide-left"}"}>
          <.offer_container offer={@offer} class="p-5 text-neutral-800 bg-white" target={@target} recipient={@recipient}>
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
          <.offer_container offer={@offer} target={@target} recipient={@recipient}>
            <div class="flex justify-center items-center bg-white">
              <%= if @offer.media_piece.banner_image do %>
                <img
                  src={
                    QlariusWeb.ThreeTapBanner.url(
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
        </div>
      </div>

      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-2 #{if @phase > 2, do: "fade-out"}"}>
          <.offer_container offer={@offer} class="px-3 py-2" target={@target} recipient={@recipient}>
            <a class="block w-full h-full" href={~p"/jump/#{@offer}"} target="_blank">
              <div class="text-blue-800 font-bold text-lg underline">
                {@offer.media_piece.title}
              </div>
              <div class="text-gray-700 text-sm mb-1" style="line-height: 1.15rem">
                {@offer.media_piece.body_copy}
              </div>
              <div class="text-green-500 text-xs">
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
            class="p-3 bg-gray-100 flex flex-col justify-center text-center text-neutral-600 select-none"
            target={@target}
            recipient={@recipient}
          >
            <div class="text-green-500 -mt-3">
              <.icon name="hero-check" class="w-6 h-6" />
            </div>
            <div class="font-semibold text-sm uppercase text-gray-400">
              ATTENTION PAID™
            </div>
            <%
              # Get totals from ThreeTap context
              {me_file_collect_total, recipient_collect_total} =
                ThreeTap.calculate_offer_totals(@offer.id, @recipient)
            %>
            <div class="text-sm text-gray-400">
              Collected: <span class="font-semibold">{format_usd(me_file_collect_total)}</span>
            </div>
            <%= if @recipient do %>
              <div class="text-sm text-gray-400 -mt-1">
                Given: <span class="font-semibold">{format_usd(recipient_collect_total)}</span>
              </div>
            <% end %>
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
    <div class="flex text-center text-xs font-light absolute bottom-0 left-0 right-0">
      <div class={[
        "py-2 flex-1 flex items-center justify-center",
        if(@phase_1_complete?, do: "bg-gray-200", else: "bg-gray-600 text-white")
      ]}>
        <%= if @phase_1_complete? do %>
          <.icon name="hero-check" class="text-green-500 w-4 h-4" />
        <% else %>
          <span>TAP: </span>
          <span class="font-bold ml-1">$0.05</span>
        <% end %>
      </div>
      <div class={[
        "py-2 flex-1 flex items-center justify-center border-l border-gray-400",
        if(@phase_1_complete?, do: "bg-gray-500 text-white", else: "bg-gray-500 text-gray-400")
      ]}>
        <span>JUMP: </span>
        <span class="font-bold ml-1">{format_usd(@phase_2_amount)}</span>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :offer, Offer, required: true
  attr :recipient, :any, default: nil
  slot :inner_block, required: true

  defp offer_container(assigns) do
    assigns = assign_new(assigns, :target, fn -> nil end)

    ~H"""
    <div
      phx-click="click-offer"
      phx-value-offer-id={@offer.id}
      phx-value-recipient-id={@recipient && @recipient.id}
      phx-target={@target}
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
