defmodule QlariusWeb.TiqitArqade.Host do
  @moduledoc """
  Shared Tiqit public arqade host behavior: creator tipping scope, Sponster
  announcer, and in-page auth sheet for browse LiveViews on `/tiqit/arqade/*`.
  """

  alias Qlarius.Referrals
  alias Qlarius.Tiqit.Arcade.PublicPage
  alias QlariusWeb.SponsterRecipientSurface

  @doc false
  def tiqit_host?(socket), do: socket.assigns[:base_path] == "/tiqit"

  @doc """
  Initializes a Tiqit browse page without a single creator in scope (discovery).
  """
  def init_browse_scope(socket, return_to) do
    socket
    |> Phoenix.Component.assign(:tiqit_host?, true)
    |> Phoenix.Component.assign(:return_to, return_to)
    |> Phoenix.Component.assign(:creator, nil)
    |> Phoenix.Component.assign(:recipient, nil)
    |> Phoenix.Component.assign(:tipping_enabled?, false)
    |> Phoenix.Component.assign(:auth_referral_context, Referrals.Context.none())
    |> assign_auth_sheet_defaults()
  end

  @doc """
  Initializes creator-scoped tipping for catalog, creator, group, and piece pages.
  """
  def init_creator_scope(socket, creator, return_to) do
    %{creator: creator, recipient: recipient, tipping_enabled?: tipping_enabled?} =
      PublicPage.load_creator_tipping(creator, return_to)

    socket =
      socket
      |> Phoenix.Component.assign(:tiqit_host?, true)
      |> Phoenix.Component.assign(:return_to, return_to)
      |> Phoenix.Component.assign(:creator, creator)
      |> Phoenix.Component.assign(:recipient, recipient)
      |> Phoenix.Component.assign(:tipping_enabled?, tipping_enabled?)
      |> assign_auth_referral_context(creator)
      |> assign_auth_sheet_defaults()

    if recipient do
      socket
      |> SponsterRecipientSurface.init_assigns(recipient, tip_only?: true)
      |> maybe_subscribe()
    else
      socket
    end
  end

  @doc false
  def auth_sheet_enabled?(assigns) do
    flag_on? =
      Application.get_env(:qlarius, :auth_sheet, [])
      |> Keyword.get(:on_qlink_page, false)

    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? and anonymous?
  end

  @doc false
  def handle_event("open-sponster-drawer", _params, socket) do
    {:handled, SponsterRecipientSurface.open_drawer(socket)}
  end

  def handle_event("open_auth_sheet", params, socket) do
    brand = Map.get(params, "brand", "tiqit")
    {:handled, schedule_auth_sheet_open(socket, brand)}
  end

  def handle_event(event, params, socket) do
    case SponsterRecipientSurface.handle_event(event, params, socket) do
      {:handled, socket} -> {:handled, socket}
      :unhandled -> :unhandled
    end
  end

  @doc false
  def handle_info(:open_sponster_drawer_from_embed, socket) do
    {:handled, SponsterRecipientSurface.open_drawer(socket)}
  end

  def handle_info({:open_auth_sheet, brand}, socket) do
    case SponsterRecipientSurface.handle_info({:open_auth_sheet, brand}, socket) do
      {:handled, socket} -> {:handled, socket}
      :unhandled -> {:handled, schedule_auth_sheet_open(socket, brand)}
    end
  end

  def handle_info(msg, socket) do
    case SponsterRecipientSurface.handle_info(msg, socket) do
      {:handled, socket} -> {:handled, socket}
      :unhandled -> :unhandled
    end
  end

  defp assign_auth_sheet_defaults(socket) do
    socket
    |> Phoenix.Component.assign(:show_auth_sheet, false)
    |> Phoenix.Component.assign(:auth_sheet_connect_brand, :tiqit)
    |> Phoenix.Component.assign(:show_connect_modal, false)
    |> Phoenix.Component.assign(:connect_modal_brand, :tiqit)
  end

  defp assign_auth_referral_context(socket, creator) do
    context =
      case creator do
        %{users: [owner_user | _]} ->
          Referrals.Context.from_creator(owner_user)

        _ ->
          Referrals.Context.none()
      end

    Phoenix.Component.assign(socket, :auth_referral_context, context)
  end

  defp maybe_subscribe(socket) do
    if Phoenix.LiveView.connected?(socket) do
      SponsterRecipientSurface.subscribe(socket)
    else
      socket
    end
  end

  defp schedule_auth_sheet_open(socket, brand) do
    socket
    |> Phoenix.Component.assign(:show_auth_sheet, true)
    |> Phoenix.Component.assign(:auth_sheet_connect_brand, normalize_auth_sheet_brand(brand))
    |> Phoenix.Component.assign(:show_connect_modal, false)
  end

  defp normalize_auth_sheet_brand(nil), do: :tiqit
  defp normalize_auth_sheet_brand(b) when b in [:qadabra, :sponster, :tiqit], do: b

  defp normalize_auth_sheet_brand(b) when is_binary(b) do
    case String.downcase(String.trim(b)) do
      "sponster" -> :sponster
      "tiqit" -> :tiqit
      "qadabra" -> :qadabra
      _ -> :tiqit
    end
  end

  defp normalize_auth_sheet_brand(_), do: :tiqit
end
