defmodule QlariusWeb.HomeLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Money

  alias QlariusWeb.Layouts

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_path, "/home")
      |> assign(:title, "Home")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns}>
      <div class="flex flex-row flex-wrap justify-between items-center px-4 py-3 mb-6">
        <h2 class="text-lg font-bold">{@current_scope.user.alias}</h2>
        <p class="flex items-center gap-1">
          <.icon name="hero-map-pin-solid" class="h-5 w-5 text-gray-500" />
          {@current_scope.home_zip}
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold tracking-tight text-base-content/50">
              Sell your attention.
            </h2>
            <img src="/images/Sponster_logo_color_horiz.svg" alt="Sponster" class="h-6 w-auto" />
          </div>

          <div class="grid grid-cols-2 gap-4 mb-4">
            <div
              class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
              phx-click={JS.navigate("/ads")}
            >
              <div class="text-3xl font-bold leading-none">{@current_scope.ads_count}</div>
              <div class="text-md font-medium text-base-content/60">ads</div>
            </div>

            <div
              class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
              phx-click={JS.navigate("/ads")}
            >
              <div class="text-3xl font-bold leading-none">
                {format_usd(@current_scope.offered_amount)}
              </div>
              <div class="text-md font-medium text-base-content/60">offered</div>
            </div>
          </div>

          <div
            class="bg-sponster-200 dark:bg-sponster-800 text-base-content/80 rounded-lg border border-sponster-300 dark:border-sponster-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-sponster-300 dark:hover:bg-sponster-700 hover:border-sponster-400 dark:hover:border-sponster-400"
            phx-click={JS.navigate("/wallet")}
          >
            <div class="text-3xl font-bold leading-none">
              {format_usd(@current_scope.wallet_balance)}
            </div>
            <div class="text-md font-medium text-base-content/60">wallet balance</div>
          </div>
        </div>

        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold tracking-tight text-base-content/50">Own your data.</h2>
            <img src="/images/YouData_logo_color_horiz.svg" alt="YouData" class="h-6 w-auto" />
          </div>

          <.link navigate={~p"/me_file"}>
            <div class="bg-youdata-200 dark:bg-youdata-900 text-base-content/80 rounded-lg border border-youdata-300 dark:border-youdata-500 p-3 flex flex-col items-center justify-center cursor-pointer transition-all duration-200 hover:bg-youdata-300 dark:hover:bg-youdata-800 hover:border-youdata-400 dark:hover:border-youdata-400">
              <div class="text-3xl font-bold leading-none">
                <%= Qlarius.YouData.MeFiles.MeFile.tag_count(@current_scope.user.me_file) %>
              </div>
              <div class="text-md font-medium text-base-content/60">tags</div>
            </div>
          </.link>
        </div>

        <div class="bg-base-200 rounded-lg p-4">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold tracking-tight text-base-content/50">Buy your media.</h2>
            <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-6 w-auto" />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center">
              <div class="text-3xl font-bold leading-none">2</div>
              <div class="text-md font-medium text-base-content/60">active tiqits</div>
            </div>

            <div class="bg-tiqit-200 dark:bg-tiqit-900 text-base-content/80 rounded-lg border border-tiqit-300 dark:border-tiqit-600 p-3 flex flex-col items-center justify-center">
              <div class="text-3xl font-bold leading-none">7</div>
              <div class="text-md font-medium text-base-content/60">expiring tiqits</div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.mobile>
    """
  end
end
