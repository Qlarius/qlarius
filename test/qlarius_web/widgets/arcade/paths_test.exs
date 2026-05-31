defmodule QlariusWeb.Widgets.Arcade.PathsTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Widgets.Arcade.Paths

  describe "discover/1" do
    test "mobile, widget, and tiqit roots" do
      assert Paths.discover("") == "/arqade"
      assert Paths.discover("/widgets") == "/widgets/arqade"
      assert Paths.discover("/tiqit") == "/tiqit/arqade"
    end
  end

  describe "group/2" do
    test "tiqit omits /group segment" do
      assert Paths.group("/tiqit", 42) == "/tiqit/arqade/42"
      assert Paths.group("", 42) == "/arqade/group/42"
    end
  end

  describe "piece/2" do
    test "tiqit uses /piece segment" do
      assert Paths.piece("/tiqit", 7) == "/tiqit/arqade/piece/7"
      assert Paths.piece("", 7) == "/arqade/7"
    end
  end

  describe "creator/2" do
    test "creator landing under each host" do
      assert Paths.creator("", 3) == "/arqade/creator/3"
      assert Paths.creator("/tiqit", 3) == "/tiqit/arqade/creator/3"
    end
  end

  describe "resolve_base_path/2" do
    test "prefers existing assign" do
      assert Paths.resolve_base_path("/tiqit/arqade", "/tiqit") == "/tiqit"
    end

    test "detects host from uri" do
      assert Paths.resolve_base_path("https://app.example/tiqit/arqade/catalog/1", nil) == "/tiqit"
      assert Paths.resolve_base_path("https://app.example/widgets/arqade", nil) == "/widgets"
      assert Paths.resolve_base_path("https://app.example/arqade", nil) == ""
    end
  end
end
