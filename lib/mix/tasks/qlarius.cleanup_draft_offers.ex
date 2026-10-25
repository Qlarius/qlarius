defmodule Mix.Tasks.Qlarius.CleanupDraftOffers do
  use Mix.Task

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Campaigns.Campaign

  @shortdoc "Deletes offers for draft campaigns (campaigns.launched_at is NULL)"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} = OptionParser.parse(args, strict: [confirm: :boolean])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    confirm? = opts[:confirm] == true

    Repo.transaction(fn ->
      rows =
        Repo.all(
          from(o in Offer,
            join: c in Campaign,
            as: :campaign,
            on: c.id == o.campaign_id,
            where: is_nil(c.launched_at),
            group_by: [c.id, c.title],
            order_by: [desc: count(o.id)],
            select: %{
              campaign_id: c.id,
              title: c.title,
              total_offers: count(o.id),
              current_offers: count(o.id) |> filter(o.is_current == true),
              pending_offers: count(o.id) |> filter(o.is_current == false)
            }
          )
        )

      total_offers = Enum.reduce(rows, 0, fn row, acc -> acc + row.total_offers end)

      Mix.shell().info("Draft campaigns with offers: #{length(rows)}")

      Enum.each(rows, fn row ->
        Mix.shell().info(
          "campaign_id=#{row.campaign_id} offers=#{row.total_offers} current=#{row.current_offers} pending=#{row.pending_offers} title=#{inspect(row.title)}"
        )
      end)

      Mix.shell().info("Total offers matched: #{total_offers}")

      if confirm? do
        {deleted, _} =
          Repo.delete_all(
            from(o in Offer,
              join: c in Campaign,
              on: c.id == o.campaign_id,
              where: is_nil(c.launched_at)
            )
          )

        Mix.shell().info("Deleted offers: #{deleted}")
        %{mode: :deleted, campaigns: length(rows), deleted: deleted}
      else
        Mix.shell().info("Dry run only. Re-run with --confirm to delete.")
        %{mode: :dry_run, campaigns: length(rows), matched: total_offers}
      end
    end)
  end
end
