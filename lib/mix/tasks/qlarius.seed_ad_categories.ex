defmodule Mix.Tasks.Qlarius.SeedAdCategories do
  @moduledoc """
  Upserts the flat Sponster ad taxonomy from
  `priv/seeds/ad_categories/sponster_categories_flat.csv`.

      mix qlarius.seed_ad_categories
      mix qlarius.seed_ad_categories --dry-run
      mix qlarius.seed_ad_categories --cohort 261002-k7q2
      mix qlarius.seed_ad_categories --path other.csv

  New rows get one fresh cohort per run unless `--cohort` is given. Existing
  rows keep their cohort.
  """
  use Mix.Task

  alias Qlarius.Sponster.Ads.AdCategorySeed

  @shortdoc "Seed the flat Sponster ad taxonomy (idempotent)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [cohort: :string, dry_run: :boolean, path: :string])

    Mix.Task.run("app.start")

    case AdCategorySeed.run(opts) do
      {:ok, report} ->
        print_report(report)

      {:error, {:invalid_rows, errors}} ->
        Mix.shell().error("Import failed, nothing saved:")
        Enum.each(errors, &Mix.shell().error("  #{&1.row_id}: #{inspect(&1.errors)}"))
        exit({:shutdown, 1})

      {:error, reason} ->
        Mix.shell().error("Import failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp print_report(report) do
    if report.dry_run, do: Mix.shell().info("Dry run, nothing saved.")

    Mix.shell().info("""
    Cohort for new rows: #{report.cohort}
    Loaded:    #{report.loaded}
    Inserted:  #{report.inserted}
    Updated:   #{report.updated}
    Unchanged: #{report.unchanged}
    Legacy rows kept: #{report.legacy_rows}
    Missing from file: #{length(report.missing)}#{missing_list(report.missing)}
    """)
  end

  defp missing_list([]), do: ""
  defp missing_list(ids), do: " (" <> Enum.join(ids, ", ") <> ")"
end
