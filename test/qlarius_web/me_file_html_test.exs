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

    test "a short query is not a search", %{list: list} do
      assert MeFileHTML.filter_tag_map_by_search(list, "do") == list
    end

    test "a short word does not match inside an unrelated name", %{list: list} do
      assert MeFileHTML.filter_tag_map_by_search(list, "cat") == []
    end

    test "a search term matches only a tag on the map", %{list: list} do
      filtered = MeFileHTML.filter_tag_map_by_search(list, "ceramics", %{201 => ["ceramics"]})

      assert length(filtered) == 1
      [parent] = elem(hd(filtered), 1)
      assert elem(parent, 1) == "Pet Type"

      assert MeFileHTML.filter_tag_map_by_search(list, "ceramics", %{999 => ["ceramics"]}) == []
    end

    test "a topic name leads a tag value, which leads a meta tag, then a search term",
         %{category: category} do
      by_name = {1, "Green Buying", 1, []}
      by_value = {2, "Shade", 2, [{21, "Evergreen", 1}]}
      by_meta = {4, "Campus", 4, [{41, "State", 1}]}
      by_term = {3, "Party", 3, [{31, "Democrat", 1}]}

      list = [{category, [by_term, by_meta, by_value, by_name]}]

      filtered =
        MeFileHTML.filter_tag_map_by_search(list, "green", %{
          31 => ["green party"],
          41 => %{terms: [], metas: ["bowling green"]}
        })

      [parents] = Enum.map(filtered, &elem(&1, 1))
      assert Enum.map(parents, &elem(&1, 1)) == ["Green Buying", "Shade", "Campus", "Party"]
    end

    test "a search term or meta tag is cited when it is not already on the card", %{
      category: category
    } do
      by_name = {1, "Home Type", 1, [{11, "Apartment", 1}]}
      by_term = {6, "Personal Income (Annual)", 2, [{221, "Prefer not to say", 1}]}
      by_meta = {8, "Language Primary", 3, [{67, "English", 1}]}

      list = [{category, [by_term, by_meta, by_name]}]

      fields = %{
        6 => %{terms: ["salary", "take home pay"], metas: []},
        8 => %{terms: [], metas: ["home language"]}
      }

      filtered = MeFileHTML.filter_tag_map_by_search(list, "home", fields)
      notes = MeFileHTML.search_match_notes(filtered, "home", fields)

      assert notes[1] == nil
      assert notes[6] == "Match: take home pay"
      assert notes[8] == "Match: home language"
    end

    test "a meta tag is cited ahead of a search term", %{category: category} do
      parent = {4, "Campus", 1, [{41, "State", 1}]}
      list = [{category, [parent]}]

      fields = %{4 => %{terms: ["greenhouse"], metas: ["green room"]}}

      filtered = MeFileHTML.filter_tag_map_by_search(list, "green", fields)
      notes = MeFileHTML.search_match_notes(filtered, "green", fields)

      assert notes[4] == "Match: green room"
    end
  end

  describe "filter_tag_map_by_status/3" do
    setup do
      category = {1, "Demographics", 1}
      green = {10, "Age", 1, [{101, "30", 1}]}
      yellow = {20, "Diet", 2, [{201, "Vegan", 1}]}
      skipped = {30, "Income", 3, [{301, "Skip", 1}]}

      list = [{category, [green, yellow, skipped]}]

      quality = %{
        10 => %{status: :green, reasons: []},
        20 => %{status: :yellow, reasons: []},
        30 => %{status: :skipped, reasons: []}
      }

      {:ok, list: list, category: category, green: green, yellow: yellow, quality: quality}
    end

    test "all keeps every tag", %{list: list, quality: quality} do
      assert MeFileHTML.filter_tag_map_by_status(list, "all", quality) == list
      assert MeFileHTML.filter_tag_map_by_status(list, nil, quality) == list
    end

    test "a color keeps only that status", %{
      list: list,
      category: category,
      yellow: yellow,
      quality: quality
    } do
      assert MeFileHTML.filter_tag_map_by_status(list, "yellow", quality) == [
               {category, [yellow]}
             ]
    end

    test "a skip is not green", %{list: list, category: category, green: green, quality: quality} do
      assert MeFileHTML.filter_tag_map_by_status(list, "green", quality) == [{category, [green]}]
    end

    test "neutral keeps a skip and a tag with no status", %{
      list: list,
      category: category,
      quality: quality
    } do
      blank = {40, "Hobby", 4, [{401, "Chess", 1}]}
      list = [{category, [blank | elem(hd(list), 1)]}]

      assert MeFileHTML.filter_tag_map_by_status(list, "neutral", quality) == [
               {category, [blank, {30, "Income", 3, [{301, "Skip", 1}]}]}
             ]
    end

    test "drops a category with nothing in that color", %{quality: quality} do
      list = [{{2, "Other", 1}, [{40, "Hobby", 1, [{401, "Chess", 1}]}]}]

      assert MeFileHTML.filter_tag_map_by_status(list, "red", quality) == []
    end

    test "a color pill appears only when that status has tags", %{list: list, quality: quality} do
      assert MeFileHTML.visible_tag_statuses(list, quality) == ~w(all green yellow neutral)
    end

    test "an all-green file has no status selector", %{category: category, green: green} do
      list = [{category, [green]}]
      quality = %{10 => %{status: :green, reasons: []}}

      assert MeFileHTML.visible_tag_statuses(list, quality) == []
    end

    test "one status besides green also hides the selector", %{
      category: category,
      yellow: yellow
    } do
      list = [{category, [yellow]}]
      quality = %{20 => %{status: :yellow, reasons: []}}

      assert MeFileHTML.visible_tag_statuses(list, quality) == []
    end
  end
end
