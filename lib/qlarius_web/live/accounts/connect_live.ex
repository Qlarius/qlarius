defmodule QlariusWeb.ConnectLive do
  @moduledoc """
  First-party Connect page: thin shell around `AuthSheet` so public
  sign-in and sign-up share one mobile-number flow (known phone →
  connect; new phone → short registration).

  Query params:

    * `return_to` — local path honored by `redirect_if_user_is_authenticated`
    * `popup=1` — after AuthSheet finalize, navigate to `/auth/popup_done`
    * `ref` / `invite` — silent referral context for new accounts
  """
  use QlariusWeb, :live_view

  alias Qlarius.Qlink.Urls
  alias Qlarius.Referrals.Context, as: ReferralContext

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}
  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  def mount(params, session, socket) do
    return_to = Urls.sanitize_return_to(Map.get(params, "return_to"))
    popup? = Map.get(params, "popup") in ["1", "true"]

    referral_context =
      ReferralContext.from_url(Map.get(params, "ref") || Map.get(params, "invite")) ||
        ReferralContext.from_url(Map.get(session, "referral_code")) ||
        ReferralContext.none()

    socket =
      socket
      |> assign(:page_title, "Connect")
      |> assign(:return_to, return_to)
      |> assign(:popup?, popup?)
      |> assign(:show_auth_sheet, true)
      |> assign(:auth_referral_context, referral_context)

    {:ok, socket}
  end

  def handle_event("close_auth_sheet", _params, socket) do
    if socket.assigns.popup? do
      {:noreply, push_event(socket, "qadabra:close-popup", %{})}
    else
      target = socket.assigns.return_to || ~p"/"
      {:noreply, push_navigate(socket, to: target)}
    end
  end

  def handle_event("referral_code_from_storage", %{"code" => code}, socket) do
    if is_nil(socket.assigns.auth_referral_context) do
      {:noreply, assign(socket, :auth_referral_context, ReferralContext.from_url(code))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("referral_code_from_storage", _params, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div id="connect-page" phx-hook="ConnectPage" class="min-h-screen flex flex-col bg-base-200/40">
      <div id="connect-referral-loader" phx-hook="RegistrationReferralCode" class="hidden" />
      <div class="flex-shrink-0 py-8 md:py-12 flex justify-center">
        <img
          src="/images/qadabra_full_gray_opt.svg"
          alt="Qadabra"
          class="h-12 md:h-16 w-auto"
        />
      </div>

      <.live_component
        module={QlariusWeb.Components.AuthSheet}
        id="connect-auth-sheet"
        show={@show_auth_sheet}
        surface={:on_connect_page}
        referral_context={@auth_referral_context}
        client_ip={assigns[:user_ip] || "0.0.0.0"}
        connect_brand={:qadabra}
        popup={@popup?}
        on_cancel={JS.push("close_auth_sheet")}
      />
    </div>
    """
  end
end
