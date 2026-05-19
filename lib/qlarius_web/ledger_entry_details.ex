defmodule QlariusWeb.LedgerEntryDetails do
  @moduledoc """
  Ad-event ledger entry detail payloads for admin views.
  """

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Targets
  alias Qlarius.Sponster.Recipient
  def ad_event_details(ad_event) do
    ad_event =
      ad_event
      |> Repo.preload([
        :campaign,
        campaign: [:marketer],
        media_piece: [:media_piece_type, :ad_category]
      ])

    recipient =
      if ad_event.recipient_id do
        Repo.get(Recipient, ad_event.recipient_id)
      end

    matching_tags =
      case ad_event.matching_tags_snapshot do
        nil -> []
        snapshot -> Targets.snapshot_to_tuples(snapshot)
      end

    %{
      type: :ad_event,
      ad_event: ad_event,
      media_piece: ad_event.media_piece,
      matching_tags: matching_tags,
      campaign_title: ad_event.campaign && ad_event.campaign.title,
      marketer_name: marketer_name(ad_event.campaign),
      recipient: recipient,
      recipient_name: recipient && recipient.name
    }
  end

  defp marketer_name(%{marketer: %{business_name: name}}), do: name
  defp marketer_name(_), do: "Unknown"

end
