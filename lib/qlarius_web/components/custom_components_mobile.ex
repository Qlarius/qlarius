defmodule QlariusWeb.Components.CustomComponentsMobile do
  use QlariusWeb, :html

  import QlariusWeb.Money

  alias Qlarius.Accounts.Scope

  attr :balance, :any, required: true

  def wallet_balance(assigns) do
    ~H"""
    <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500">
      <span class="font-bold">{format_usd(@balance)}</span>
    </span>
    """
  end

  attr :count, :integer, required: true

  def tag_count(assigns) do
    ~H"""
    <span class="inline-flex items-center w-auto text-lg bg-youdata-200 dark:bg-youdata-900 text-base-content px-3 py-1 rounded-lg border border-youdata-300 dark:border-youdata-500">
      <span class="font-bold">{@count}&nbsp;tags</span>
    </span>
    """
  end

  attr :current_path, :string, required: true
  attr :current_scope, Scope, required: true

  def onboarding_tip(assigns) do
    assigns =
      assign(assigns, :tip_data, get_tip_data(assigns.current_path, assigns.current_scope))

    ~H"""
    <%= if @tip_data do %>
      <div
        id="onboarding-tip"
        class="fixed bottom-20 max-w-md mx-auto left-4 right-4 z-45 transform translate-y-full opacity-0"
        phx-mounted={
          JS.transition(
            {"ease-out duration-500", "translate-y-full opacity-0", "translate-y-0 opacity-100"},
            time: 300
          )
        }
      >
        <div class="shadow-xl bg-base-100 dark:bg-base-200 !border-2 !border-primary rounded-xl overflow-hidden">
          <%!-- Header banner with logo and close button --%>
          <div class="bg-base-200 dark:bg-base-300 px-4 py-3 flex items-center justify-center relative">
            <img src={@tip_data.logo} alt="" class="h-8 w-auto" />
            <button
              phx-click={
                JS.hide(
                  to: "#onboarding-tip",
                  transition:
                    {"ease-in duration-200", "translate-y-0 opacity-100",
                     "translate-y-full opacity-0"}
                )
              }
              class="absolute right-4 btn btn-default btn-xs btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content" />
            </button>
          </div>

          <%!-- Content area --%>
          <div class="p-6">
            <%= if @tip_data.screen == :home do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block font-bold text-2xl">You're in!</span>
                  <span class="block mt-2">
                    Welcome to the Home screen - a great overview of all your Qadabra activities.
                  </span>
                  <span class="block mt-2">
                    Have a quick look around by exploring the screens in the menu dock below.
                  </span>
                  <span class="block w-full flex justify-center mt-2">
                    <.icon
                      name="hero-chevron-down"
                      class="h-10 w-10 mt-5 text-primary animate-bounce"
                    />
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :wallet do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">
                    This is your new attention wallet. It's empty now, but we'll soon fix that.
                  </span>
                  <span class="block mt-2">Add funds by selling your attention (Ads).</span>
                  <span class="block mt-2">
                    Spend funds on your media and to support your favorite creators.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :me_file do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">Build and manage your MeFile tags here.</span>
                  <span class="block mt-2">
                    You've got {@current_scope.trait_count} starter tags. Add more tags to your MeFile to optimize sponsorships and fuel your wallet.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :tagger do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">
                    The Tagger is where you will add new tags to your MeFile here.
                  </span>
                  <span class="block mt-2">
                    Start above with the "ESSENTIALS" - a bucket of high-value tags to make a great first step.
                  </span>
                  <span class="block mt-2">
                    Over time, build out your MeFile to optimize sponsorships and fuel your wallet.
                  </span>
                </p>
              </div>
            <% end %>

            <%= if @tip_data.screen == :ads do %>
              <div>
                <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
                  <span class="block">Engage your ads and sell your attention.</span>
                  <span class="block mt-2">These starter ads will seed your wallet.</span>
                  <span class="block mt-2">Build your MeFile to pull the right ads for you.</span>
                </p>
              </div>
            <% end %>
          </div>
          <%!-- End content area --%>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_tip_data(current_path, current_scope) do
    balance_zero? = Decimal.compare(current_scope.wallet_balance, Decimal.new(0)) == :eq
    few_tags? = current_scope.trait_count < 5

    case current_path do
      path when path in ["/", "/home"] and balance_zero? ->
        %{screen: :home, logo: "/images/qadabra_logo_squares_color.svg"}

      "/wallet" when balance_zero? ->
        %{screen: :wallet, logo: "/images/qadabra_logo_squares_color.svg"}

      "/me_file" when few_tags? ->
        %{screen: :me_file, logo: "/images/YouData_logo_color_horiz.svg"}

      "/me_file_builder" when few_tags? ->
        %{screen: :tagger, logo: "/images/YouData_logo_color_horiz.svg"}

      "/ads" when balance_zero? ->
        %{screen: :ads, logo: "/images/Sponster_logo_color_horiz.svg"}

      _ ->
        nil
    end
  end
end
