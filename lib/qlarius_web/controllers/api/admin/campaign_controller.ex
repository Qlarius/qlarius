defmodule QlariusWeb.Api.Admin.CampaignController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.Campaigns
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.Campaign
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    campaigns = Campaigns.list(params)
    json(conn, %{count: length(campaigns), campaigns: Enum.map(campaigns, &summary/1)})
  end

  def show(conn, %{"id" => id}) do
    case Campaigns.fetch(id) do
      {:ok, campaign} -> json(conn, %{campaign: encode(campaign)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, params) do
    case Campaigns.create(params, dry_run: Responder.dry_run?(params)) do
      {:ok, %{result: "created"} = result} -> conn |> put_status(201) |> json(encode(result))
      {:ok, result} -> json(conn, encode(result))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, campaign} <- load(id),
         {:ok, result} <- Campaigns.update(campaign, params, dry_run: Responder.dry_run?(params)) do
      json(conn, encode(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def bid_preview(conn, params) do
    case Campaigns.bid_preview(params) do
      {:ok, preview} -> json(conn, encode(preview))
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def launch(conn, %{"id" => id} = params) do
    with {:ok, campaign} <- load(id),
         {:ok, campaign} <- Campaigns.launch(campaign, params) do
      json(conn, %{
        result: "launched",
        campaign_id: campaign.id,
        launched_at: campaign.launched_at
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def deactivate(conn, %{"id" => id} = params) do
    with {:ok, campaign} <- load(id),
         {:ok, result} <- Campaigns.deactivate(campaign, dry_run: Responder.dry_run?(params)) do
      json(conn, encode(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def reactivate(conn, %{"id" => id}) do
    with {:ok, campaign} <- load(id),
         {:ok, result} <- Campaigns.reactivate(campaign) do
      json(conn, encode(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def offers(conn, %{"id" => id} = params) do
    with {:ok, campaign} <- load(id) do
      json(conn, encode(Campaigns.offers(campaign, params)))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, campaign} <- load(id),
         {:ok, result} <- Campaigns.delete(campaign, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp load(id) do
    case Repo.get(Campaign, id) do
      nil -> {:error, :not_found}
      campaign -> {:ok, campaign}
    end
  end

  defp summary(campaign) do
    Map.take(campaign, [
      :id,
      :api_ref,
      :title,
      :marketer_id,
      :is_ptp,
      :is_payable,
      :is_throttled,
      :launched_at,
      :deactivated_at
    ])
  end

  defp encode(value), do: value |> money() |> dates()

  defp money(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp money(%_{} = value), do: value
  defp money(value) when is_map(value), do: Map.new(value, fn {k, v} -> {k, money(v)} end)
  defp money(value) when is_list(value), do: Enum.map(value, &money/1)
  defp money(value), do: value

  defp dates(value), do: value
end
