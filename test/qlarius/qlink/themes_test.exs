defmodule Qlarius.Qlink.ThemesTest do
  use ExUnit.Case, async: true

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.Themes

  describe "apply/1" do
    test "returns theme and background for every template" do
      for id <- Themes.template_ids() do
        applied = Themes.apply(id)
        assert applied.theme_config["template_id"] == id
        assert applied.background_config["type"] in ["solid", "gradient"]
        assert applied.theme_config["embed_theme"] in ["light", "dark"]
        assert applied.theme_config["gutter"] =~ ~r/^#[0-9a-fA-F]{6}$/
      end
    end

    test "returns nil for unknown ids" do
      assert Themes.apply("nope") == nil
    end
  end

  describe "resolve/1" do
    test "legacy empty config is unthemed" do
      assert Themes.resolve(nil) == nil
      assert Themes.resolve(%{}) == nil
      assert Themes.resolve(%QlinkPage{theme_config: nil}) == nil
    end

    test "sanitizes and marks themed pages" do
      theme =
        Themes.resolve(%{"template_id" => "midnight", "font" => "comic", "text_color" => "red"})

      assert theme["themed?"]
      assert theme["font"] == "outfit"
      assert theme["text_color"] == "#f5f5f4"
    end
  end

  describe "sanitize_background_config/1" do
    test "keeps hex solids and safe gradients" do
      assert Themes.sanitize_background_config(%{"type" => "solid", "value" => "#ff00aa"}) ==
               %{"type" => "solid", "value" => "#ff00aa"}

      g = "linear-gradient(90deg, #000 0%, #fff 100%)"

      assert Themes.sanitize_background_config(%{"type" => "gradient", "value" => g})["value"] ==
               g
    end

    test "drops hotlinked image URLs and css url() attacks" do
      assert Themes.sanitize_background_config(%{
               "type" => "image",
               "value" => "https://evil.example/bg.jpg"
             }) == %{}

      assert Themes.sanitize_background_config(%{
               "type" => "gradient",
               "value" => "linear-gradient(url(https://evil.example/x))"
             }) == %{}
    end

    test "keeps waffle filenames" do
      assert Themes.sanitize_background_config(%{"type" => "image", "file" => "bg.webp"}) ==
               %{"type" => "image", "file" => "bg.webp"}
    end
  end

  describe "first_party_src/2" do
    test "allows same-origin paths and rejects hotlinks" do
      assert Themes.first_party_src("/images/qlink-themes/x.jpg", nil) ==
               "/images/qlink-themes/x.jpg"

      assert Themes.first_party_src("https://cdn.example/hot.jpg", nil) == nil
    end
  end

  describe "css_vars/1" do
    test "emits custom properties for a template" do
      theme = Themes.resolve(Themes.apply("classic").theme_config)
      vars = Themes.css_vars(theme)
      assert vars =~ "--qlink-text:"
      assert vars =~ "--qlink-font:"
      assert vars =~ "--qlink-gutter:"
      assert vars =~ "Figtree"
    end
  end

  describe "page_classes/1" do
    test "includes button style modifier for themed pages" do
      theme = Themes.resolve(Themes.apply("coastal").theme_config)
      classes = Themes.page_classes(theme)
      assert "qlink-public-page--themed" in classes
      assert "qlink-public-page--btn-fill" in classes
      assert "qlink-public-page--shape-rounded" in classes
    end
  end

  describe "header_mode/2" do
    test "hero requires a profile photo" do
      theme = Themes.resolve(Themes.apply("sunset").theme_config)
      assert Themes.header_mode(theme, %QlinkPage{profile_photo: nil}) == "avatar"
      assert Themes.header_mode(theme, %QlinkPage{profile_photo: "me.jpg"}) == "hero"
    end
  end
end
