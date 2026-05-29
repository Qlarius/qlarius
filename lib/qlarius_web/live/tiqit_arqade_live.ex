defmodule QlariusWeb.TiqitArqadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.ContentSharing
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.PublicPage
  alias QlariusWeb.SponsterRecipientSurface
  alias QlariusWeb.WalletBalanceSync

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
  def handle_params(%{"token" => token}, _uri, socket) do
    case ContentSharing.get_invitation_by_token(token) do
      {:ok, resolved} ->
        invitation = resolved.invitation
        group_id = invitation.content_group_id
        piece_id = invitation.content_piece_id

        case PublicPage.load(group_id, content_piece_id: piece_id) do
          {:ok, page} ->
            creator = Repo.preload(page.creator, :users)
            page = %{page | creator: creator}
            recipient = page.recipient

            socket =
              socket
              |> assign_page(page, recipient)
              |> assign(:return_to, invitation_return_to(token, invitation.share_type))
              |> assign(:invitation, resolved)
              |> assign(:invitation_token, token)
              |> assign(:gift_piece_id, invitation.content_piece_id)
              |> assign(:show_invitation_overlay, true)
              |> assign(:pin_error, nil)
              |> assign(:pin_verified?, false)
              |> assign_invitation_referral_context(invitation)
              |> SponsterRecipientSurface.init_assigns(recipient, tip_only?: true)
              |> maybe_subscribe()

            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply, page_not_found(socket)}
        end

      {:error, :not_found} ->
        {:noreply, page_not_found(socket)}
    end
  end

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
          |> assign_page(page, recipient)
          |> assign(:return_to, return_to)
          |> assign(:invitation, nil)
          |> assign(:invitation_token, nil)
          |> assign(:gift_piece_id, nil)
          |> assign(:show_invitation_overlay, false)
          |> assign(:pin_error, nil)
          |> assign(:pin_verified?, false)
          |> assign_auth_referral_context(page.creator)
          |> SponsterRecipientSurface.init_assigns(recipient, tip_only?: true)
          |> maybe_subscribe()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, page_not_found(socket)}
    end
  end

  defp assign_page(socket, page, recipient) do
    socket
    |> assign(:page, page)
    |> assign(:group, page.group)
    |> assign(:creator, page.creator)
    |> assign(:recipient, recipient)
    |> assign(:tipping_enabled?, page.tipping_enabled?)
    |> assign(:selected_piece_id, page.selected_piece_id)
    |> assign(:page_title, page.group.title || "Tiqit Arqade")
    |> assign(:parent_request_uri, parent_request_uri(socket))
  end

  defp maybe_subscribe(socket) do
    if connected?(socket) do
      SponsterRecipientSurface.subscribe(socket)
    else
      socket
    end
  end

  defp page_not_found(socket) do
    socket
    |> put_flash(:error, "Page not found")
    |> redirect(to: ~p"/")
  end

  @impl true
  def handle_event("open-sponster-drawer", _params, socket) do
    {:noreply, SponsterRecipientSurface.open_drawer(socket)}
  end

  def handle_event("dismiss-invitation-overlay", _params, socket) do
    {:noreply, assign(socket, :show_invitation_overlay, false)}
  end

  def handle_event("reopen-invitation-overlay", _params, socket) do
    {:noreply, assign(socket, :show_invitation_overlay, true)}
  end

  def handle_event("verify-claim-pin", %{"pin" => pin}, socket) do
    case socket.assigns[:invitation] do
      %{will_call: will_call} when not is_nil(will_call) ->
        case ContentSharing.verify_claim_pin(will_call, pin) do
          {:ok, _} ->
            {:noreply, assign(socket, pin_verified?: true, pin_error: nil)}

          {:error, :invalid_pin} ->
            {:noreply,
             socket
             |> refresh_invitation()
             |> assign(:pin_error, "That PIN didn't match. Try again.")}

          {:error, :locked} ->
            {:noreply,
             assign(socket, :pin_error, "Too many attempts. This ticket is locked.")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("claim-gift", _params, socket) do
    resolved = socket.assigns[:invitation]
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(resolved) or is_nil(resolved.will_call) ->
        {:noreply, socket}

      not socket.assigns.pin_verified? ->
        {:noreply, assign(socket, :pin_error, "Enter your claim PIN first.")}

      is_nil(scope) or is_nil(scope.true_user) ->
        {:noreply, trigger_connect(socket)}

      true ->
        case ContentSharing.redeem_gift(resolved.will_call, scope) do
          {:ok, _will_call} ->
            {:noreply,
             socket
             |> put_flash(:info, "Your ticket is ready!")
             |> push_navigate(to: claim_navigate_path(resolved.invitation))}

          {:error, :not_claimable} ->
            {:noreply,
             socket
             |> put_flash(:error, "This gift can no longer be claimed.")
             |> refresh_invitation()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not claim the gift. Please try again.")}
        end
    end
  end

  def handle_event(event, params, socket) do
    case SponsterRecipientSurface.handle_event(event, params, socket) do
      {:handled, socket} -> {:noreply, socket}
      :unhandled -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:inline_arcade_embed_ready, pid}, socket) when is_pid(pid) do
    {:noreply, WalletBalanceSync.register_inline_embed(socket, pid)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) do
    if ref == socket.assigns[:arcade_embed_monitor_ref] do
      {:noreply, WalletBalanceSync.clear_inline_embed(socket)}
    else
      {:noreply, socket}
    end
  end

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

  defp invitation_return_to(token, "gift"), do: "/tiqit/gift/#{token}"
  defp invitation_return_to(token, _), do: "/tiqit/share/#{token}"

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

  defp refresh_invitation(socket) do
    case ContentSharing.get_invitation_by_token(socket.assigns[:invitation_token]) do
      {:ok, resolved} -> assign(socket, :invitation, resolved)
      _ -> socket
    end
  end

  defp trigger_connect(socket) do
    if auth_sheet_enabled?(socket.assigns) do
      send(self(), {:open_auth_sheet, :tiqit})
      socket
    else
      push_navigate(socket, to: "/login?return_to=#{socket.assigns.return_to}")
    end
  end

  defp claim_navigate_path(%{content_group_id: group_id, content_piece_id: piece_id})
       when not is_nil(piece_id),
       do: "/tiqit/arqade/#{group_id}/#{piece_id}"

  defp claim_navigate_path(%{content_group_id: group_id}),
    do: "/tiqit/arqade/#{group_id}"

  @doc false
  def format_remaining_claim_time(nil), do: "a limited time"

  def format_remaining_claim_time(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      hours >= 1 -> "#{hours} #{maybe_plural(hours, "hour")}"
      minutes >= 1 -> "#{minutes} #{maybe_plural(minutes, "minute")}"
      true -> "less than a minute"
    end
  end

  defp maybe_plural(1, word), do: word
  defp maybe_plural(_n, word), do: word <> "s"

  defp assign_invitation_referral_context(socket, invitation) do
    source = if invitation.share_type == "gift", do: :content_gift, else: :content_share

    context =
      case Accounts.get_user(invitation.sender_user_id) do
        %Accounts.User{} = user ->
          Referrals.Context.from_content_invitation(user, source, invitation.id)

        _ ->
          Referrals.Context.none()
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
