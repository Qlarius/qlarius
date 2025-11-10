# Retry Offer Creation for Campaign

The worker had a bug where `Repo.stream()` was called without a transaction, causing it to fail silently.

This has been fixed. To retry offer creation for your campaign:

## Option 1: Use the UI (recommended)

For launched campaigns, click the **"Refresh Offers"** button in the campaign card footer. This will:
1. Delete all existing offers
2. Re-enqueue the OBAN worker to create fresh offers

## Option 2: Re-launch the campaign (via IEx)

This will clear existing offers, reset launched_at, and create fresh ones:

```elixir
campaign_id = 114  # Replace with your campaign ID

campaign = Qlarius.Repo.get!(Qlarius.Sponster.Campaigns.Campaign, campaign_id)
{:ok, _} = Qlarius.Sponster.Campaigns.launch_campaign(campaign)
```

## Option 3: Manually enqueue the worker (via IEx)

If the campaign is already launched, you can manually enqueue the worker:

```elixir
campaign_id = 114  # Replace with your campaign ID

%{"campaign_id" => campaign_id}
|> Qlarius.Jobs.CreateInitialPendingOffersWorker.new()
|> Oban.insert()
```

## Verify offers were created

```elixir
campaign_id = 114

alias Qlarius.Repo
import Ecto.Query

# Count offers
from(o in Qlarius.Sponster.Offer, where: o.campaign_id == ^campaign_id, select: count(o.id))
|> Repo.one()

# View offers
from(o in Qlarius.Sponster.Offer, 
  where: o.campaign_id == ^campaign_id,
  select: %{id: o.id, me_file_id: o.me_file_id, target_band_id: o.target_band_id, offer_amt: o.offer_amt}
)
|> Repo.all()
```

## Check logs

The worker now logs its progress. Check the logs with:

```bash
tail -f log/dev.log | grep CreateInitialPendingOffersWorker
```

