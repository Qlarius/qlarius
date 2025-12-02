defmodule Qlarius.Sponster.Campaigns.CampaignPubSub do
  @moduledoc """
  PubSub broadcasting for real-time campaign updates.

  This module handles publishing and subscribing to campaign-related events,
  allowing LiveViews to receive real-time updates when campaigns change.
  """

  @doc """
  Subscribes the current process to updates for a specific campaign.
  """
  def subscribe_to_campaign(campaign_id) do
    Phoenix.PubSub.subscribe(Qlarius.PubSub, "campaign:#{campaign_id}")
  end

  @doc """
  Subscribes the current process to updates for all campaigns belonging to a marketer.
  """
  def subscribe_to_marketer_campaigns(marketer_id) do
    Phoenix.PubSub.subscribe(Qlarius.PubSub, "marketer:#{marketer_id}:campaigns")
  end

  @doc """
  Broadcasts that a specific campaign has been updated.
  """
  def broadcast_campaign_updated(campaign_id) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "campaign:#{campaign_id}",
      {:campaign_updated, campaign_id}
    )
  end

  @doc """
  Broadcasts that a campaign has been updated to all subscribers of the marketer's campaigns.
  """
  def broadcast_marketer_campaign_updated(marketer_id, campaign_id) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "marketer:#{marketer_id}:campaigns",
      {:campaign_updated, campaign_id}
    )
  end

  @doc """
  Broadcasts that a target's population has been completed.
  This triggers offer creation.
  """
  def broadcast_target_populated(campaign_id) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "campaign:#{campaign_id}",
      {:target_populated, campaign_id}
    )
  end

  @doc """
  Broadcasts that offers have been created for a campaign.
  """
  def broadcast_offers_created(campaign_id, count) do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "campaign:#{campaign_id}",
      {:offers_created, campaign_id, count}
    )
  end

  @doc """
  Broadcasts that pending offers have been activated.
  General broadcast to all campaigns.
  """
  def broadcast_offers_activated do
    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "campaigns:offers_activated",
      {:offers_activated}
    )
  end
end
