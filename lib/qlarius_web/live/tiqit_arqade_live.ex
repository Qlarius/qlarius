defmodule QlariusWeb.TiqitArqadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.PublicPage
  alias QlariusWeb.SponsterRecipientSurface

  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.SponsterPublicPage, only: [sponster_stack: 1]
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.Widgets.UnauthCTA

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    group_id = parse_id(params["content_group_id"])

    content_piece_id =
      case params["content_piece_id"] do
        nil -> nil
        id -> parse_id(id)
      end

    case PublicPage.load(group_id, content_piece_id: content_piece_id) do
      {:ok, page} ->
        creator = Repo.preload(page.creator, :users)
        page = %{page | creator: creator}
        recipient = page.recipient
        return_to = return_to_path(group_id, page.selected_piece_id)

        socket =
          socket
          |> assign(:page, page)
          |> assign(:group, page.group)
          |> assign(:creator, page.creator)
          |> assign(:recipient, recipient)
          |> assign(:tipping_enabled?, page.tipping_enabled?)
          |> assign(:selected_piece_id, page.selected_piece_id)
          |> assign(:return_to, return_to)
          |> assign(:page_title, page.group.title || "Tiqit Arqade")
          |> assign(:parent_request_uri, parent_request_uri(socket))
          |> assign_auth_referral_context(page.creator)
          |> SponsterRecipientSurface.init_assigns(recipient, tip_only?: true)

        socket =
          if connected?(socket) do
            socket
            |> SponsterRecipientSurface.subscribe()
          else
            socket
          end

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("open-sponster-drawer", _params, socket) do
    {:noreply, SponsterRecipientSurface.open_drawer(socket)}
  end

  def handle_event(event, params, socket) do
    case SponsterRecipientSurface.handle_event(event, params, socket) do
      {:handled, socket} -> {:noreply, socket}
      :unhandled -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:open_sponster_drawer_from_embed, socket) do
    {:noreply, SponsterRecipientSurface.open_drawer(socket)}
  end

  def handle_info(msg, socket) do
    case SponsterRecipientSurface.handle_info(msg, socket) do
      {:handled, socket} -> {:noreply, socket}
      :unhandled -> {:noreply, socket}
    end
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(_), do: nil

  defp return_to_path(group_id, nil), do: "/tiqit/arqade/#{group_id}"

  defp return_to_path(group_id, piece_id),
    do: "/tiqit/arqade/#{group_id}/#{piece_id}"

  defp parent_request_uri(socket) do
    case socket.host_uri do
      %URI{host: host} = uri when is_binary(host) -> uri
      _ -> nil
    end
  end

  defp assign_auth_referral_context(socket, creator) do
    context =
      case creator do
        %{users: [owner_user | _]} ->
          Qlarius.Referrals.Context.from_creator(owner_user)

        _ ->
          Qlarius.Referrals.Context.none()
      end

    assign(socket, :auth_referral_context, context)
  end

  def auth_sheet_enabled?(assigns) do
    flag_on? =
      Application.get_env(:qlarius, :auth_sheet, [])
      |> Keyword.get(:on_qlink_page, false)

    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? and anonymous?
  end
end
