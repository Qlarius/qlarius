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

  describe "indefinite_article/1 and type_with_article/2" do
    test "uses an for vowel-leading types" do
      assert Catalog.indefinite_article(:article) == "an"
      assert Catalog.indefinite_article(:episode) == "an"
      assert Catalog.indefinite_article(:album) == "an"
    end

    test "uses a for consonant-leading types" do
      assert Catalog.indefinite_article(:lesson) == "a"
      assert Catalog.indefinite_article(:class) == "a"
    end

    test "type_with_article/2 combines article and label" do
      assert Catalog.type_with_article(:lesson) == "a lesson"
      assert Catalog.type_with_article(:episode) == "an episode"
      assert Catalog.type_with_article(:class) == "a class"
    end
  end
end
