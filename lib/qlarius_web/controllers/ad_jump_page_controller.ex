defmodule QlariusWeb.AdJumpPageController do
  use QlariusWeb, :controller

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offers
  alias Qlarius.Sponster.Ads.ThreeTap
  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Plugs.HostAwareSession

  @doc """
  Renders the jump page with countdown. Payment is NOT processed here.
  Payment is processed by `collect/2` which is called via AJAX when redirect occurs.
  """
  def jump(conn, params) do
    offer_id = params["id"]
    recipient_id = params["recipient_id"]

    case Offers.get_offer_with_media_piece(offer_id) do
      nil ->
        conn
        |> put_flash(:error, "This offer is no longer available.")
        |> redirect(to: resolve_exit_path(conn, params))

      offer ->
        exit_path = resolve_exit_path(conn, params)
        conn = put_session(conn, "qlarius_ad_jump_exit_path", exit_path)

        # Pass data to template - payment will be processed at redirect time
        render(conn, :jump,
          layout: false,
          offer: offer,
          recipient_id: recipient_id,
          autosplit_disabled: params["autosplit"] == "0",
          use_location_replace: use_location_replace?(conn),
          exit_path: exit_path
        )
    end
  end

  @doc """
  Processes the jump payment. Called via AJAX right before redirect to advertiser.
  This ensures payment only happens if user waits for the redirect.
  """
  def collect(conn, params) do
    offer_id = params["offer_id"]
    recipient_id = params["recipient_id"]

    case Offers.get_offer_with_media_piece(offer_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Offer not found"})

      offer ->
        # Get recipient if provided
        recipient =
          if recipient_id && recipient_id != "", do: Repo.get(Recipient, recipient_id), else: nil

        offer = Repo.preload(offer, me_file: [])

        split_amount =
          if params["autosplit"] == "0" do
            0
          else
            (offer.me_file && offer.me_file.split_amount) || 0
          end

        # Get request info for ad event
        ip = get_client_ip(conn)
        host = conn.host

        # Create the jump ad event (processes payment) - this also enqueues the completion worker
        case ThreeTap.create_jump_ad_event(offer, recipient, split_amount, ip, host) do
          {:ok, _ad_event} ->
            conn
            |> put_status(:ok)
            |> json(%{success: true, jump_url: offer.media_piece.jump_url})

          {:error, _reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to process payment"})
        end
    end
  end

  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] -> forwarded |> String.split(",") |> List.first() |> String.trim()
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp use_location_replace?(conn) do
    cfg = Application.get_env(:qlarius, :ad_jump, [])

    if Keyword.get(cfg, :use_location_replace, true) do
      case Keyword.get(cfg, :replace_strategy, :universal) do
        :universal -> true
        :iab_only -> Plug.Conn.get_session(conn, "qlarius_iab") != nil
        _ -> true
      end
    else
      false
    end
  end

  defp resolve_exit_path(conn, params) do
    default =
      if HostAwareSession.host_under_qadabra?(conn.host) do
        ~p"/ads"
      else
        ~p"/"
      end

    normalize_internal_path(params["return_to"]) ||
      Plug.Conn.get_session(conn, "qlarius_ad_jump_exit_path") |> normalize_internal_path() ||
      referer_internal_path(conn) ||
      default
  end

  defp normalize_internal_path(nil), do: nil

  defp normalize_internal_path(path) when is_binary(path) do
    path = String.trim(path)

    cond do
      path == "" ->
        nil

      String.contains?(path, ["\n", "\r"]) ->
        nil

      true ->
        uri = URI.parse(path)

        cond do
          not is_nil(uri.scheme) or not is_nil(uri.host) ->
            nil

          not is_binary(uri.path) ->
            nil

          String.starts_with?(uri.path, "//") ->
            nil

          not String.starts_with?(uri.path, "/") ->
            nil

          true ->
            uri
            |> Map.put(:fragment, nil)
            |> URI.to_string()
        end
    end
  end

  defp referer_internal_path(conn) do
    case Plug.Conn.get_req_header(conn, "referer") do
      [referer | _] when is_binary(referer) ->
        case URI.parse(referer) do
          %URI{host: host} = uri when is_binary(host) and host == conn.host ->
            uri
            |> Map.merge(%{scheme: nil, host: nil, port: nil, fragment: nil})
            |> URI.to_string()
            |> normalize_internal_path()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
