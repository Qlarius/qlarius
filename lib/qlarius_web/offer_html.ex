defmodule QlariusWeb.OfferHTML do
  use QlariusWeb, :html

  alias Qlarius.Sponster.{Offer, Recipient}
  alias Qlarius.YouData.MeFiles.MeFile
  alias QlariusWeb.Uploaders.ThreeTapBanner
  alias Qlarius.Sponster.Ads.ThreeTap
  import Ecto.Query, except: [update: 2, update: 3]

  import QlariusWeb.Money

  @phase_1_amount Decimal.new("0.05")

  attr :phase, :integer, default: 0
  attr :offer, Offer, required: true
  attr :recipient, :any, default: nil
  attr :split_amount, :integer, default: 0
  attr :target, :any, default: nil
  attr :current_scope, :any, required: true

  def clickable_offer(assigns) do
    split_amount = assigns.current_scope.user.me_file.split_amount
    phase_2_amount = Decimal.sub(assigns.offer.offer_amt, @phase_1_amount)
    assigns = assign(assigns, :phase_2_amount, phase_2_amount)
    assigns = assign_new(assigns, :target, fn -> nil end)

    ~H"""
    <div
      class="offer-container rounded-md border border-base-500/50 overflow-hidden cursor-pointer"
      style="width: 347px; height: 152px;"
    >
      <div class="absolute inset-0 overflow-hidden">
        <div class={"offer-phase phase-0 #{if @phase > 0, do: "slide-left"}"}>
          <.offer_container
            offer={@offer}
            class="p-5 text-base-content bg-base-100"
            target={@target}
            recipient={@recipient}
          >
            <div class="text-2xl font-bold mb-2">{format_usd(@offer.offer_amt)}</div>
            <div class="mb-4 text-base-content/50">
              {@offer.media_piece.ad_category.ad_category_name}
            </div>
            <div class="flex justify-between w-full">
              <div class="text-blue-400">
                <%= if @offer.matching_tags_snapshot && Enum.any?(String.split(@offer.matching_tags_snapshot, ","), fn key -> String.contains?(String.downcase(key), "zip code") end) do %>
                  <.icon name="hero-map-pin-solid" class="w-5 h-5" />
                <% end %>
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
            <div class="flex justify-center items-center bg-base-100">
              <%= if @offer.media_piece.banner_image do %>
                <img
                  src={
                    ThreeTapBanner.url(
                      {@offer.media_piece.banner_image, @offer.media_piece},
                      :original
                    )
                  }
                  alt="Ad image"
                  style="width: 345px; height: 115px;"
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

      <div class="absolute inset-0 overflow-hidden" style="height: 150px;">
        <div class={"offer-phase phase-2 #{if @phase > 2, do: "hidden"}"}>
          <.offer_container offer={@offer} class="px-3 py-2" target={@target} recipient={@recipient}>
            <a class="block w-full h-full" href={~p"/jump/#{@offer}"} target="_blank">
              <div class="text-blue-500 font-bold text-lg underline">
                {@offer.media_piece.title}
              </div>
              <div class="text-base-700 text-sm mb-1" style="line-height: 1.15rem">
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
            class="p-3 bg-base-200 flex flex-col justify-center text-center text-base-content select-none"
            target={@target}
            recipient={@recipient}
          >
            <div class="text-green-500 -mt-3">
              <.icon name="hero-check" class="w-6 h-6" />
            </div>
            <div class="font-semibold text-sm text-gray-400">
              Attention Paid™
            </div>
            <% # Get totals from ThreeTap context
            {me_file_collect_total, recipient_collect_total} =
              ThreeTap.calculate_offer_totals(@offer.id, @recipient) %>
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
    <div
      class="flex items-center justify-center text-center text-xs font-light absolute bottom-0 left-0 right-0"
      style="height: 35px;"
    >
      <div
        class={[
          "flex-1 flex items-center justify-center",
          if(@phase_1_complete?, do: "bg-base-200", else: "text-base-content")
        ]}
        style="height: 35px;"
      >
        <%= if @phase_1_complete? do %>
          <.icon name="hero-check" class="text-green-500 w-4 h-4" />
        <% else %>
          <span>TAP: </span>
          <span class="font-bold ml-1">$0.05</span>
        <% end %>
      </div>
      <div
        class={[
          "flex-1 flex items-center justify-center border-l border-gray-400",
          if(@phase_1_complete?, do: "bg-base-200 text-base-content", else: "bg-base-300 text-base-content/20")
        ]}
        style="height: 35px;"
      >
        <span>JUMP: </span>
        <span class="font-bold ml-1">{format_usd(@phase_2_amount)}</span>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :offer, Offer, required: true
  attr :recipient, :any, default: nil
  attr :target, :any, default: nil
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
        "relative overflow-hidden cursor-pointer",
        @class
      ]}
      style="height: 150px;"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
