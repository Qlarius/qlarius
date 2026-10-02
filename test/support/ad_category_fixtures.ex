defmodule Qlarius.AdCategoryFixtures do
  @moduledoc """
  Ad taxonomy rows and the media pieces that point at them.
  """

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategory, MediaPiece, MediaPieceType}

  def row_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])
    category_id = Map.get(attrs, :category_id, "SP01")

    defaults = %{
      row_id: "#{category_id}-#{rem(n, 90) + 10}#{n}",
      category_id: category_id,
      category_name: "Category #{category_id}",
      category_label: "Label #{category_id}",
      ad_label: "Label #{n}",
      sort_order: n,
      cohort: "legacy"
    }

    %AdCategory{}
    |> AdCategory.create_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def marketer_fixture do
    %Marketer{}
    |> Marketer.changeset(%{business_name: "Ad Cat Marketer #{System.unique_integer()}"})
    |> Repo.insert!()
  end

  def ensure_three_tap_type! do
    unless Repo.get(MediaPieceType, 1) do
      Repo.insert!(%MediaPieceType{
        id: 1,
        name: "three_tap",
        desc: "3-tap",
        ad_phase_count_to_complete: 2,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
    end

    :ok
  end

  def media_piece_fixture(%AdCategory{} = row, marketer \\ nil) do
    ensure_three_tap_type!()
    marketer = marketer || marketer_fixture()

    %MediaPiece{}
    |> MediaPiece.changeset(%{
      title: "Banner #{System.unique_integer()}",
      media_piece_type_id: 1,
      ad_category_id: row.id,
      marketer_id: marketer.id,
      active: true,
      banner_image: "banner.png",
      display_url: "example.com",
      jump_url: "https://example.com/jump"
    })
    |> Repo.insert!()
  end
end
