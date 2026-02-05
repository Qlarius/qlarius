defmodule QlariusWeb.AdJumpPageController do
  use QlariusWeb, :controller

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offers
  alias Qlarius.Sponster.Ads.ThreeTap
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Wallets.MeFileStatsBroadcaster

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
        |> redirect(to: ~p"/ads")

      offer ->
        # Pass data to template - payment will be processed at redirect time
        render(conn, :jump,
          layout: false,
          offer: offer,
          recipient_id: recipient_id
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
        recipient = if recipient_id && recipient_id != "", do: Repo.get(Recipient, recipient_id), else: nil

        # Get split_amount from the offer's me_file
        offer = Repo.preload(offer, me_file: [])
        split_amount = (offer.me_file && offer.me_file.split_amount) || 0

        # Get request info for ad event
        ip = get_client_ip(conn)
        host = conn.host

        # Create the jump ad event (processes payment) - this also enqueues the completion worker
        case ThreeTap.create_jump_ad_event(offer, recipient, split_amount, ip, host) do
          {:ok, _ad_event} ->
            # Broadcast wallet balance update
            MeFileStatsBroadcaster.broadcast_balance_updated(
              offer.me_file_id,
              Qlarius.Wallets.get_me_file_ledger_header_balance(offer.me_file)
            )
            MeFileStatsBroadcaster.broadcast_offers_updated(offer.me_file_id)

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
end
