defmodule QlariusWeb.SlideToCollectTestLive do
  use QlariusWeb, :live_view
  import QlariusWeb.Components.AdsComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Slide to Collect - Test")
     |> assign(:current_path, "/test/slide-to-collect")
     |> assign(:test_amount, Decimal.new("0.35"))
     |> assign(:test_offer_id, 999)}
  end

  @impl true
  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    require Logger
    Logger.info("🎉 PAYMENT COLLECTED! Offer ID: #{offer_id}, Amount: #{socket.assigns.test_amount}")

    {:noreply,
     socket
     |> put_flash(:info, "Test payment collected: $#{socket.assigns.test_amount}")
     |> push_event("collection-success", %{})}
  end

  def handle_event("video_collect_timeout", _params, socket) do
    require Logger
    Logger.info("⏱️ TIMEOUT! User did not complete slide in time")

    {:noreply, put_flash(socket, :error, "Time expired - try again")}
  end

  def handle_event("update_amount", %{"amount" => amount_str}, socket) do
    amount = Decimal.new(amount_str)
    {:noreply, assign(socket, :test_amount, amount)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:test_offer_id, socket.assigns.test_offer_id + 1)
     |> clear_flash()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 p-8">
      <div class="max-w-2xl mx-auto">
        <h1 class="text-3xl font-bold mb-2">Slide to Collect Component - Test View</h1>
        <p class="text-base-content/60 mb-8">
          This is a temporary view for designing and testing the slide-to-collect component.
        </p>

        <div class="card bg-base-200 shadow-xl mb-8">
          <div class="card-body">
            <h2 class="card-title">Test Controls</h2>
            <form phx-change="update_amount">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Amount to collect:</span>
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={Decimal.to_string(@test_amount)}
                  name="amount"
                  class="input input-bordered"
                />
              </div>
            </form>
            <button class="btn btn-primary mt-4" phx-click="reset">
              Reset Slider
            </button>
          </div>
        </div>

        <div class="card bg-base-300 shadow-xl">
          <div class="card-body">
            <h2 class="card-title mb-4">Slider Component</h2>
            <.slide_to_collect
              id={"slide-to-collect-#{@test_offer_id}"}
              offer_id={@test_offer_id}
              amount={@test_amount}
            />
          </div>
        </div>

        <div class="alert alert-info mt-8">
          <.icon name="hero-information-circle" class="w-6 h-6" />
          <div>
            <p class="font-semibold">How to test:</p>
            <ul class="list-disc list-inside mt-2 text-sm">
              <li>Drag the slider from left to right to collect payment</li>
              <li>Watch the countdown timer decrease from :07 to :00</li>
              <li>See the vertical green progress bar decrease in height</li>
              <li>Slide reaches the dotted circle destination on the right</li>
              <li>On success, slider turns green and pulses for 0.5s</li>
              <li>If time expires, the slider resets</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
