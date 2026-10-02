defmodule Qlarius.Sponster.Ads.AdCategoriesTest do
  use Qlarius.DataCase, async: false

  import Qlarius.AdCategoryFixtures

  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategories, AdCategory, AdCategorySeed, MediaPiece}

  setup do
    Repo.delete_all(AdCategory)
    :ok
  end

  describe "cohorts" do
    test "new_cohort is a date plus a 4 character suffix" do
      cohort = AdCategories.new_cohort(~D[2026-10-02])
      assert cohort =~ ~r/^261002-[a-z0-9]{4}$/
      assert AdCategory.valid_cohort?(cohort)
    end

    test "valid_cohort? rejects bad dates and shapes" do
      assert AdCategory.valid_cohort?("legacy")
      refute AdCategory.valid_cohort?("261302-abcd")
      refute AdCategory.valid_cohort?("261002")
      refute AdCategory.valid_cohort?("261002-ABCD")
    end

    test "the database rejects a bad cohort" do
      row = row_fixture()

      assert_raise Postgrex.Error, ~r/ad_categories_cohort_check/, fn ->
        Repo.query!("UPDATE ad_categories SET cohort = 'nope' WHERE id = $1", [row.id])
      end
    end

    test "list_cohorts puts legacy last" do
      row_fixture(cohort: "legacy")
      row_fixture(cohort: "261001-aaaa")
      row_fixture(cohort: "261002-bbbb")

      assert ["261002-bbbb", "261001-aaaa", "legacy"] =
               Enum.map(AdCategories.list_cohorts(), & &1.cohort)
    end
  end

  describe "row numbering" do
    test "next row_id follows the highest number in the category" do
      row_fixture(row_id: "SP06-01", category_id: "SP06")
      row_fixture(row_id: "SP06-10", category_id: "SP06")

      assert {:ok, row} =
               AdCategories.create_row(%{"category_id" => "SP06", "ad_label" => "Bagels"})

      assert row.row_id == "SP06-11"
      assert row.category_name == "Category SP06"
      assert row.cohort =~ ~r/^\d{6}-[a-z0-9]{4}$/
    end

    test "a new category takes the next code above the max, so SP24 is never reused" do
      row_fixture(row_id: "SP23-01", category_id: "SP23")
      row_fixture(row_id: "SP25-01", category_id: "SP25")

      assert {:ok, row} =
               AdCategories.create_row(%{
                 "new_category" => %{
                   "category_name" => "Space",
                   "category_label" => "Space Stuff"
                 },
                 "ad_label" => "Rockets"
               })

      assert row.category_id == "SP26"
      assert row.row_id == "SP26-01"
    end

    test "create_row rejects an unknown category" do
      assert {:error, :unknown_category} =
               AdCategories.create_row(%{"category_id" => "SP99", "ad_label" => "X"})
    end

    test "create_rows shares one cohort and one new category" do
      row_fixture(row_id: "SP02-01", category_id: "SP02")

      assert {:ok, %{cohort: cohort, rows: [a, b]}} =
               AdCategories.create_rows(
                 %{
                   "new_category" => %{"category_name" => "New", "category_label" => "New Things"}
                 },
                 "First\n\nSecond\n"
               )

      assert {a.row_id, b.row_id} == {"SP03-01", "SP03-02"}
      assert a.cohort == cohort and b.cohort == cohort
    end

    test "create_rows rolls back every label when one is invalid" do
      row_fixture(row_id: "SP02-01", category_id: "SP02", ad_label: "Taken")

      assert {:error, {"Taken", %Ecto.Changeset{}}} =
               AdCategories.create_rows(%{"category_id" => "SP02"}, "Fresh\nTaken")

      assert Repo.aggregate(AdCategory, :count) == 1
    end
  end

  describe "validation" do
    test "row_id and category_id never change on update" do
      row = row_fixture(row_id: "SP01-01")
      assert {:error, :immutable_key} = AdCategories.update_row(row, %{"row_id" => "SP01-02"})
      assert {:error, :immutable_key} = AdCategories.update_row(row, %{"category_id" => "SP02"})
      assert {:ok, _} = AdCategories.update_row(row, %{"row_id" => "SP01-01", "ad_label" => "Ok"})
    end

    test "age_min must match age_gated" do
      row = row_fixture()

      assert {:error, cs} = AdCategories.update_row(row, %{"age_gated" => true})
      assert "is required when age gated" in errors_on(cs).age_min

      assert {:error, cs} = AdCategories.update_row(row, %{"age_gated" => true, "age_min" => 19})
      assert "must be 18 or 21" in errors_on(cs).age_min

      assert {:error, cs} = AdCategories.update_row(row, %{"age_min" => 21})
      assert "must be blank unless age gated" in errors_on(cs).age_min

      assert {:ok, %{age_min: 21}} =
               AdCategories.update_row(row, %{"age_gated" => true, "age_min" => 21})
    end

    test "ad_label is unique, short, and free of em dashes" do
      row_fixture(ad_label: "Pizza")
      row = row_fixture()

      assert {:error, cs} = AdCategories.update_row(row, %{"ad_label" => "Pizza"})
      assert "has already been taken" in errors_on(cs).ad_label

      assert {:error, cs} =
               AdCategories.update_row(row, %{"ad_label" => String.duplicate("a", 47)})

      assert errors_on(cs).ad_label != []

      assert {:error, cs} = AdCategories.update_row(row, %{"ad_label" => "Pizza \u2014 Pie"})
      assert "must not contain em dashes" in errors_on(cs).ad_label
    end

    test "cohort must be valid on update" do
      row = row_fixture()
      assert {:error, cs} = AdCategories.update_row(row, %{"cohort" => "soon"})
      assert errors_on(cs).cohort != []
    end

    test "rename_category updates every row" do
      row_fixture(category_id: "SP04")
      row_fixture(category_id: "SP04")

      assert {:ok, %{updated: 2}} =
               AdCategories.rename_category("SP04", %{"category_label" => "Gyms"})

      assert ["Gyms", "Gyms"] =
               AdCategories.list_rows(%{"category_id" => "SP04"}) |> Enum.map(& &1.category_label)
    end
  end

  describe "listing and search" do
    test "search matches meta words and ranks label matches first" do
      row_fixture(ad_label: "Bakeries", meta_1: "Food|Pizza dough", sort_order: 10)
      row_fixture(ad_label: "Pizza Places", sort_order: 20)
      row_fixture(ad_label: "Car Wash", sort_order: 30)

      assert ["Pizza Places", "Bakeries"] =
               AdCategories.search("pizza") |> Enum.map(& &1.ad_label)

      assert ["Bakeries"] = AdCategories.search("pizza dough") |> Enum.map(& &1.ad_label)
    end

    test "counts all media pieces per row" do
      row = row_fixture()
      media_piece_fixture(row)
      media_piece_fixture(row)

      assert [%{media_pieces_count: 2, active_media_pieces_count: 0}] = AdCategories.list_rows()
    end

    test "group_rows keeps category order" do
      row_fixture(category_id: "SP01", sort_order: 10)
      row_fixture(category_id: "SP02", sort_order: 20)
      row_fixture(category_id: "SP01", sort_order: 30)

      assert [%{category_id: "SP01", rows: [_, _]}, %{category_id: "SP02"}] =
               AdCategories.group_rows(AdCategories.list_rows())
    end

    test "picker_options skip inactive rows except the current one" do
      active = row_fixture(ad_label: "Open", meta_2: "Tag|Other")
      inactive = row_fixture(ad_label: "Closed", active: false)

      assert [%{value: id, search_text: text}] = AdCategories.picker_options()
      assert id == active.id
      assert text =~ "tag other"

      assert length(AdCategories.picker_options(inactive.id)) == 2
    end
  end

  describe "upsert_rows" do
    @csv """
    row_id,category_id,category_name,category_label,ad_label,age_gated,age_min,sales_channel_default,meta_1,meta_2,meta_3,sort_order
    SP01-01,SP01,"Apparel, Shoes & Jewelry","Clothes, Shoes & Jewelry",Women's Clothing,0,,both,Clothing,Dresses|Tops,boutique,10
    SP25-01,SP25,"Cannabis, Tobacco & Vaping","Cannabis, Smoking & Vaping",Dispensaries,1,21,local,Cannabis,Dispensary,dispensary,20
    """

    test "inserts, then reports unchanged on a second run" do
      rows = AdCategorySeed.parse_string(@csv)

      assert {:ok, %{inserted: 2, updated: 0, unchanged: 0, loaded: 2, cohort: cohort}} =
               AdCategories.upsert_rows(rows)

      assert {:ok, %{inserted: 0, updated: 0, unchanged: 2}} = AdCategories.upsert_rows(rows)

      gated = AdCategories.get_by_row_id("SP25-01")
      assert gated.age_gated and gated.age_min == 21 and gated.cohort == cohort
    end

    test "updates changed rows without moving their cohort, and reports missing rows" do
      [first, second] = AdCategorySeed.parse_string(@csv)
      legacy = row_fixture(row_id: "LEGACY-001", category_id: "LEGACY")
      {:ok, _} = AdCategories.upsert_rows([first, second], cohort: "261001-aaaa")

      changed = %{first | "ad_label" => "Womenswear"}

      assert {:ok, %{updated: 1, missing: ["SP25-01"], legacy_rows: 1}} =
               AdCategories.upsert_rows([changed], cohort: "261002-bbbb")

      row = AdCategories.get_by_row_id("SP01-01")
      assert row.ad_label == "Womenswear"
      assert row.cohort == "261001-aaaa"
      assert Repo.get(AdCategory, legacy.id)
    end

    test "dry_run saves nothing and a bad row rolls back the batch" do
      [first, second] = AdCategorySeed.parse_string(@csv)

      assert {:ok, %{inserted: 2, dry_run: true}} =
               AdCategories.upsert_rows([first, second], dry_run: true)

      assert Repo.aggregate(AdCategory, :count) == 0

      bad = %{second | "age_min" => ""}

      assert {:error, {:invalid_rows, [%{row_id: "SP25-01", errors: %{age_min: _}}]}} =
               AdCategories.upsert_rows([first, bad])

      assert Repo.aggregate(AdCategory, :count) == 0
    end

    test "the seed file loads all 304 rows" do
      rows = AdCategorySeed.parse_file!(AdCategorySeed.default_path())
      assert length(rows) == 304
      assert {:ok, %{inserted: 304}} = AdCategories.upsert_rows(rows, dry_run: true)
    end
  end

  describe "set_cohort, remap, prune, delete" do
    test "set_cohort moves rows by row_ids or category" do
      a = row_fixture(category_id: "SP07")
      row_fixture(category_id: "SP07")

      assert {:ok, %{updated: 1}} =
               AdCategories.set_cohort(%{"row_ids" => [a.row_id]}, "261002-cccc")

      assert {:ok, %{updated: 2}} = AdCategories.set_cohort(%{"category_id" => "SP07"}, "legacy")
      assert {:error, :invalid_cohort} = AdCategories.set_cohort(%{"category_id" => "SP07"}, "x")
      assert {:error, :selector_required} = AdCategories.set_cohort(%{}, "legacy")
    end

    test "remap moves media pieces and reports counts" do
      from = row_fixture()
      to = row_fixture()
      media_piece_fixture(from)
      media_piece_fixture(from)

      assert {:ok, %{moved: 2, mappings: [%{count: 2}]}} =
               AdCategories.remap_media_pieces(%{
                 "mappings" => [%{"from_row_id" => from.row_id, "to_row_id" => to.row_id}]
               })

      assert Repo.aggregate(from(mp in MediaPiece, where: mp.ad_category_id == ^to.id), :count) ==
               2
    end

    test "remap rolls back every mapping when a target is inactive" do
      a = row_fixture()
      b = row_fixture()
      closed = row_fixture(active: false)
      piece = media_piece_fixture(a)
      media_piece_fixture(b)

      assert {:error, {:row_inactive, _}} =
               AdCategories.remap_media_pieces(%{
                 "mappings" => [
                   %{"from_row_id" => a.row_id, "to_row_id" => b.row_id},
                   %{"from_row_id" => b.row_id, "to_row_id" => closed.row_id}
                 ]
               })

      assert Repo.get!(MediaPiece, piece.id).ad_category_id == a.id
    end

    test "remap by media_piece_ids with dry_run changes nothing" do
      a = row_fixture()
      b = row_fixture()
      piece = media_piece_fixture(a)

      assert {:ok, %{moved: 1, dry_run: true}} =
               AdCategories.remap_media_pieces(
                 %{"media_piece_ids" => [piece.id], "to_row_id" => b.row_id},
                 dry_run: true
               )

      assert Repo.get!(MediaPiece, piece.id).ad_category_id == a.id
    end

    test "prune skips rows that any media piece uses" do
      used = row_fixture(cohort: "261002-dddd")
      unused = row_fixture(cohort: "261002-dddd")
      media_piece_fixture(used)

      assert {:ok, %{count: 1, deleted: [id], dry_run: true}} =
               AdCategories.prune_unused(%{"cohort" => "261002-dddd"}, dry_run: true)

      assert id == unused.row_id
      assert Repo.get(AdCategory, unused.id)

      assert {:ok, %{count: 1}} = AdCategories.prune_unused(%{"cohort" => "261002-dddd"})
      refute Repo.get(AdCategory, unused.id)
      assert Repo.get(AdCategory, used.id)

      assert {:error, :selector_required} = AdCategories.prune_unused(%{})
    end

    test "delete_row refuses rows still in use" do
      row = row_fixture()
      media_piece_fixture(row)
      assert {:error, {:in_use, 1}} = AdCategories.delete_row(row)
    end
  end

  describe "media pieces" do
    test "an inactive row can't be newly assigned" do
      row = row_fixture()
      closed = row_fixture(active: false)
      piece = media_piece_fixture(row)

      changeset = MediaPiece.changeset(piece, %{"ad_category_id" => closed.id})
      refute changeset.valid?
      assert errors_on(changeset).ad_category_id != []

      assert MediaPiece.changeset(piece, %{"title" => "Renamed"}).valid?
    end
  end
end
