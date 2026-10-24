defmodule Qlarius.Sponster.Campaigns.CampaignFilters do
  @moduledoc false

  import Ecto.Query

  @doc """
  Filters a query to campaigns that have been launched and are not deactivated.

  The query must include a binding named `:campaign`.
  """
  def launched(query) do
    where(query, [campaign: c], is_nil(c.deactivated_at) and not is_nil(c.launched_at))
  end

  @doc """
  Filters a query to campaigns that are launched, not deactivated, and currently
  within their start/end date window.

  The query must include a binding named `:campaign`.
  """
  def live_now(query, %NaiveDateTime{} = now) do
    query
    |> launched()
    |> where([campaign: c], is_nil(c.start_date) or c.start_date <= ^now)
    |> where([campaign: c], is_nil(c.end_date) or c.end_date >= ^now)
  end
end
