defmodule Qlarius.Sponster.Ads.AdCategorySeed do
  @moduledoc """
  Loads the flat Sponster taxonomy CSV into `ad_categories` through
  `AdCategories.upsert_rows/2`. Safe to run repeatedly; also callable from a
  remote console where mix tasks are unavailable.
  """

  alias Qlarius.Sponster.Ads.AdCategories

  NimbleCSV.define(__MODULE__.Parser, separator: ",", escape: "\"")

  def default_path do
    Application.app_dir(:qlarius, "priv/seeds/ad_categories/sponster_categories_flat.csv")
  end

  def run(opts \\ []) do
    opts
    |> Keyword.get(:path, default_path())
    |> parse_file!()
    |> AdCategories.upsert_rows(Keyword.take(opts, [:cohort, :dry_run]))
  end

  def parse_file!(path) do
    path
    |> File.read!()
    |> String.replace_prefix("\uFEFF", "")
    |> parse_string()
  end

  def parse_string(csv) do
    [header | rows] = __MODULE__.Parser.parse_string(csv, skip_headers: false)
    header = Enum.map(header, &String.trim/1)

    rows
    |> Enum.reject(&(&1 == [""] or &1 == []))
    |> Enum.map(fn row -> header |> Enum.zip(row) |> Map.new() end)
  end
end
