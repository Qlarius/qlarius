defmodule Qlarius.Tiqit.Arcade.CatalogTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.Catalog

  describe "type_label/3" do
    test "irregular plurals" do
      assert Catalog.type_label(:class, 1) == "Class"
      assert Catalog.type_label(:class, 2) == "Classes"
      assert Catalog.type_label(:series, 2) == "Series"
    end

    test "regular plurals" do
      assert Catalog.type_label(:lesson, 1) == "Lesson"
      assert Catalog.type_label(:lesson, 48) == "Lessons"
    end

    test "lowercase for inline counts" do
      assert Catalog.type_label(:class, 1, capitalize: false) == "class"
      assert Catalog.type_label(:class, 2, capitalize: false) == "classes"
      assert Catalog.type_label(:lesson, 48, capitalize: false) == "lessons"
    end

    test "accepts string type names" do
      assert Catalog.type_label("class", 2) == "Classes"
    end
  end
end
