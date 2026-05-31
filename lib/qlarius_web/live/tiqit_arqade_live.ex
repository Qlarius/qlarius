defmodule QlariusWeb.TiqitArqadeLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.ContentSharing
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.PublicPage
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias QlariusWeb.SponsterRecipientSurface
  alias QlariusWeb.WalletBalanceSync

  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.SponsterPublicPage, only: [sponster_stack: 1]
  import QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.TiqitClassHTML, only: [format_tiqit_class_duration: 1]
  import QlariusWeb.Widgets.UnauthCTA
  import QlariusWeb.TiqitComponents

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
              |> assign(:show_invitation_overlay, true)
              |> assign(:pin_error, nil)
              |> assign(:gift_claim_succeeded, false)
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
          |> assign(:show_invitation_overlay, false)
          |> assign(:pin_error, nil)
          |> assign(:gift_claim_succeeded, false)
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
    socket =
      socket
      |> assign(:show_invitation_overlay, false)
      |> maybe_refresh_claimed_invitation()

    {:noreply, socket}
  end

  def handle_event("reopen-invitation-overlay", _params, socket) do
    {:noreply, assign(socket, :show_invitation_overlay, true)}
  end

  def handle_event("verify-claim-pin", %{"pin" => pin}, socket) do
    if authed?(socket.assigns.current_scope) do
      verify_claim_pin(socket, pin)
    else
      {:noreply, trigger_connect(socket)}
    end
  end

  def handle_event("open_auth_sheet", params, socket) do
    brand = Map.get(params, "brand", "tiqit")
    {:noreply, schedule_auth_sheet_open(socket, brand)}
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

  def handle_info(:reopen_invitation_overlay, socket) do
    {:noreply, assign(socket, :show_invitation_overlay, true)}
  end

  def handle_info({:open_auth_sheet, brand}, socket) do
    socket =
      case SponsterRecipientSurface.handle_info({:open_auth_sheet, brand}, socket) do
        {:handled, socket} -> socket
        :unhandled -> socket
      end

    {:noreply, socket}
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
      schedule_auth_sheet_open(socket, :tiqit)
    else
      push_navigate(socket, to: "/login?return_to=#{socket.assigns.return_to}")
    end
  end

  # Open the auth sheet and close the interstitial overlays (gift invitation /
  # connect modal) in the *same* render. Doing both atomically lets the closing
  # overlay's exit (backdrop fade-out) crossfade with the auth sheet's enter
  # (backdrop fade-in). Deferring the close to a later tick instead left a frame
  # where both fully-opaque backdrops stacked, causing a visible darken→lighten
  # flash. This mirrors `SponsterRecipientSurface.open_auth_sheet/2`.
  defp schedule_auth_sheet_open(socket, brand) do
    socket
    |> assign(:show_auth_sheet, true)
    |> assign(:auth_sheet_connect_brand, normalize_auth_sheet_brand(brand))
    |> assign(:show_invitation_overlay, false)
    |> assign(:show_connect_modal, false)
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

  defp verify_claim_pin(socket, pin) do
    case socket.assigns[:invitation] do
      %{will_call: will_call} when not is_nil(will_call) ->
        case ContentSharing.verify_claim_pin(will_call, pin) do
          {:ok, _} ->
            redeem_gift_after_pin(socket)

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

  defp redeem_gift_after_pin(socket) do
    resolved = socket.assigns[:invitation]
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(resolved) or is_nil(resolved.will_call) ->
        {:noreply, socket}

      is_nil(scope) or is_nil(scope.true_user) ->
        {:noreply, trigger_connect(socket)}

      true ->
        case ContentSharing.redeem_gift(resolved.will_call, scope) do
          {:ok, _will_call} ->
            {:noreply,
             socket
             |> assign(:gift_claim_succeeded, true)
             |> assign(:pin_error, nil)}

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

  defp maybe_refresh_claimed_invitation(%{assigns: %{gift_claim_succeeded: true}} = socket),
    do: refresh_invitation(socket)

  defp maybe_refresh_claimed_invitation(socket), do: socket

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

  @doc false
  def invitation_content_piece_id(nil), do: nil

  def invitation_content_piece_id(%{invitation: %{content_piece_id: id}}) when not is_nil(id),
    do: id

  def invitation_content_piece_id(_), do: nil

  @doc false
  def gift_highlight_piece_id(_invitation, true), do: nil

  def gift_highlight_piece_id(%{state: :active_gift, invitation: %{content_piece_id: id}}, false)
      when not is_nil(id),
      do: id

  def gift_highlight_piece_id(_, _), do: nil

  @doc false
  def recipient_gift_card(%{will_call: will_call, invitation: invitation}, group)
      when not is_nil(will_call) do
    content_group = gift_card_content_group(invitation, group)
    content_piece = gift_card_content_piece(invitation, group, will_call)

    content_piece =
      if content_piece && not assoc_loaded?(content_piece.content_group) do
        Map.put(content_piece, :content_group, content_group)
      else
        content_piece
      end

    will_call
    |> Map.put(:share_invitation, invitation)
    |> Map.put(:tiqit_class, invitation.tiqit_class)
    |> Map.put(:content_group, content_group)
    |> Map.put(:content_piece, content_piece)
  end

  def recipient_gift_card(_, _), do: nil

  @doc false
  def gift_access_summary(group, invitation) do
    tc = invitation.tiqit_class
    catalog = group.catalog
    scope = gift_access_scope(tc, invitation)
    piece = gift_access_piece(group, invitation)

    %{
      scope: scope,
      image_url: gift_access_image_url(scope, piece, group),
      subtitle: gift_access_subtitle(scope, piece, group, catalog),
      title: gift_access_title(scope, piece, group, catalog),
      includes: gift_access_includes(scope, group, catalog),
      duration: gift_access_duration(tc)
    }
  end

  defp gift_access_scope(%TiqitClass{content_piece_id: id}, _invitation) when not is_nil(id),
    do: :piece

  defp gift_access_scope(%TiqitClass{content_group_id: id}, _invitation) when not is_nil(id),
    do: :group

  defp gift_access_scope(%TiqitClass{catalog_id: id, content_piece_id: nil, content_group_id: nil}, _invitation)
       when not is_nil(id),
       do: :catalog

  defp gift_access_scope(nil, invitation) do
    if invitation.content_piece_id, do: :piece, else: :group
  end

  defp gift_access_scope(_tc, invitation) do
    if invitation.content_piece_id, do: :piece, else: :group
  end

  defp assoc_loaded?(%Ecto.Association.NotLoaded{}), do: false
  defp assoc_loaded?(_), do: true

  defp gift_card_content_group(invitation, group) do
    cond do
      invitation.content_group ->
        ensure_group_catalog(invitation.content_group, group)

      true ->
        group
    end
  end

  defp ensure_group_catalog(content_group, page_group) do
    if assoc_loaded?(content_group.catalog) do
      content_group
    else
      Map.put(content_group, :catalog, page_group.catalog)
    end
  end

  defp gift_card_content_piece(invitation, group, will_call) do
    cond do
      invitation.content_piece ->
        invitation.content_piece

      will_call.content_piece_id ->
        Enum.find(group.content_pieces, &(&1.id == will_call.content_piece_id))

      true ->
        nil
    end
  end

  defp gift_access_piece(group, invitation) do
    cond do
      not is_nil(invitation.content_piece) ->
        invitation.content_piece

      invitation.content_piece_id ->
        Enum.find(group.content_pieces, &(&1.id == invitation.content_piece_id))

      true ->
        nil
    end
  end

  defp gift_access_image_url(:piece, piece, group) when not is_nil(piece),
    do: content_image_url(piece, group)

  defp gift_access_image_url(:group, _piece, group), do: group_image_url(group)
  defp gift_access_image_url(:catalog, _piece, group), do: group_image_url(group)

  defp gift_access_subtitle(:piece, _piece, group, _catalog), do: group.title
  defp gift_access_subtitle(:group, _piece, _group, catalog), do: catalog.name
  defp gift_access_subtitle(:catalog, _piece, _group, catalog), do: catalog.name

  defp gift_access_title(:piece, piece, _group, _catalog) when not is_nil(piece), do: piece.title
  defp gift_access_title(:piece, _piece, group, _catalog), do: group.title
  defp gift_access_title(:group, _piece, group, _catalog), do: group.title
  defp gift_access_title(:catalog, _piece, _group, catalog), do: catalog.name

  defp gift_access_includes(:piece, _group, catalog) do
    piece_type = catalog.piece_type |> to_string()
    "Single #{piece_type}"
  end

  defp gift_access_includes(:group, group, catalog) do
    piece_count = group.content_pieces |> ContentGroup.active_content_pieces() |> length()
    piece_type = catalog.piece_type |> to_string()
    piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)
    group_type = catalog.group_type |> to_string()
    "Entire #{group_type} · #{piece_count} #{piece_label}"
  end

  defp gift_access_includes(:catalog, group, catalog) do
    group_count = length(catalog.content_groups)
    group_type = catalog.group_type |> to_string()
    group_label = if group_count == 1, do: group_type, else: pluralize(group_type)
    piece_count = Arcade.active_piece_count_for_catalog(catalog)
    piece_type = catalog.piece_type |> to_string()
    piece_label = if piece_count == 1, do: piece_type, else: pluralize(piece_type)

    if piece_count > 0 do
      "Entire #{catalog.type} · #{group_count} #{group_label}, #{piece_count} #{piece_label}"
    else
      "Entire #{catalog.type} · #{group_count} #{group_label}"
    end
  end

  defp gift_access_duration(%TiqitClass{duration_hours: hours}) when is_integer(hours) do
    "#{format_tiqit_class_duration(hours)} access"
  end

  defp gift_access_duration(%TiqitClass{duration_hours: nil}), do: "Lifetime access"
  defp gift_access_duration(_), do: nil

  defp pluralize("series"), do: "series"
  defp pluralize(word), do: word <> "s"
end
