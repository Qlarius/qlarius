defmodule QlariusWeb.CreatorDashboard.IndexTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.CreatorDashboard.Index

  describe "visible_creators/3" do
    setup do
      creators = [
        %{name: "Zed Studio"},
        %{name: "alpha media"},
        %{name: "Beta Labs"}
      ]

      {:ok, creators: creators}
    end

    test "filters by name case-insensitively", %{creators: creators} do
      assert names(Index.visible_creators(creators, "lab", :az)) == ["Beta Labs"]
    end

    test "sorts A–Z and Z–A by name", %{creators: creators} do
      assert names(Index.visible_creators(creators, "", :az)) == [
               "alpha media",
               "Beta Labs",
               "Zed Studio"
             ]

      assert names(Index.visible_creators(creators, "", :za)) == [
               "Zed Studio",
               "Beta Labs",
               "alpha media"
             ]
    end
  end

  defp names(creators), do: Enum.map(creators, & &1.name)
end
