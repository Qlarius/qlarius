defmodule QlariusWeb.MeFileHTMLTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.MeFileHTML

  describe "filter_tag_map_by_search/2" do
    setup do
      category = {1, "Demographics", 1}

      parent_a = {10, "Favorite Color", 1, [{101, "Blue", 1}, {102, "Green", 2}]}
      parent_b = {20, "Pet Type", 2, [{201, "Dog", 1}]}

      list = [{category, [parent_a, parent_b]}]
      {:ok, list: list, category: category, parent_a: parent_a, parent_b: parent_b}
    end

    test "returns full list when search is empty", %{list: list} do
      assert MeFileHTML.filter_tag_map_by_search(list, "") == list
      assert MeFileHTML.filter_tag_map_by_search(list, nil) == list
    end

    test "accepts legacy map assign and returns a sorted list", %{list: list, category: category} do
      map = Map.new(list)

      filtered = MeFileHTML.filter_tag_map_by_search(map, "color")

      assert is_list(filtered)
      assert length(filtered) == 1
      assert elem(hd(filtered), 0) == category
    end

    test "matches parent trait name and keeps all child tags", %{list: list, category: category} do
      filtered = MeFileHTML.filter_tag_map_by_search(list, "color")

      assert length(filtered) == 1
      assert elem(hd(filtered), 0) == category
      assert elem(hd(filtered), 1) == [elem(hd(list), 1) |> hd()]
    end

    test "matches child tag value and keeps entire parent family", %{list: list} do
      filtered = MeFileHTML.filter_tag_map_by_search(list, "dog")

      assert length(filtered) == 1
      [parent] = elem(hd(filtered), 1)
      assert elem(parent, 1) == "Pet Type"
      assert length(elem(parent, 3)) == 1
    end

    test "omits categories with no matches", %{list: list} do
      assert MeFileHTML.filter_tag_map_by_search(list, "zzzzz") == []
    end

    test "search is case-insensitive", %{list: list, category: category} do
      filtered = MeFileHTML.filter_tag_map_by_search(list, "BLUE")

      assert elem(hd(filtered), 0) == category
      assert elem(hd(filtered), 1) == [elem(hd(list), 1) |> hd()]
    end
  end
end
