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
        assert applied.theme_config["button"]["border"] == applied.theme_config["button"]["text"]
      end
    end

    test "returns nil for unknown ids" do
      assert Themes.apply("nope") == nil
    end
  end

  describe "document_theme/1" do
    test "pins to the template embed theme and defaults unthemed pages to light" do
      assert Themes.document_theme(Themes.resolve(Themes.apply("classic").theme_config)) ==
               "light"

      assert Themes.document_theme(Themes.resolve(Themes.apply("midnight").theme_config)) ==
               "dark"

      assert Themes.document_theme(nil) == "light"
    end
  end

  describe "template_origin/2" do
    test "applied when theme and background match the template" do
      applied = Themes.apply("classic")

      assert Themes.template_origin(applied.theme_config, applied.background_config) ==
               {:applied, "classic", "Classic"}
    end

    test "custom when tokens diverge" do
      applied = Themes.apply("classic")
      theme = Map.put(applied.theme_config, "text_color", "#ff0000")

      assert Themes.template_origin(theme, applied.background_config) ==
               {:custom, "classic", "Classic"}
    end

    test "custom when background diverges" do
      applied = Themes.apply("classic")
      bg = %{"type" => "pattern", "pattern" => "blobs"}

      assert Themes.template_origin(applied.theme_config, bg) ==
               {:custom, "classic", "Classic"}
    end

    test "none without a template" do
      assert Themes.template_origin(nil, nil) == :none
      assert Themes.template_summary(:none) == "None"

      assert Themes.template_summary({:custom, "classic", "Classic"}) ==
               "Custom (from Classic originally)"
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
      assert theme["button"]["border"] == theme["button"]["text"]
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
      result =
        Themes.sanitize_background_config(%{
          "type" => "image",
          "value" => "https://evil.example/bg.jpg"
        })

      assert result == %{"type" => "image"}
      refute Map.has_key?(result, "file")
      refute Map.has_key?(result, "value")

      assert Themes.sanitize_background_config(%{
               "type" => "gradient",
               "value" => "linear-gradient(url(https://evil.example/x))"
             }) == %{}
    end

    test "keeps waffle filenames" do
      assert Themes.sanitize_background_config(%{"type" => "image", "file" => "bg.webp"}) ==
               %{"type" => "image", "file" => "bg.webp"}
    end

    test "sanitizes pattern backgrounds" do
      cfg =
        Themes.sanitize_background_config(%{
          "type" => "pattern",
          "pattern" => "dots",
          "base" => "#95acd5",
          "fill" => "#ffffff",
          "opacity" => "50",
          "fit" => "tile"
        })

      assert cfg == %{
               "type" => "pattern",
               "pattern" => "dots",
               "base" => "#95acd5",
               "fill" => "#ffffff",
               "opacity" => 50,
               "fit" => "tile"
             }
    end

    test "falls back unknown pattern ids and clamps opacity" do
      cfg =
        Themes.sanitize_background_config(%{
          "type" => "pattern",
          "pattern" => "evil",
          "opacity" => 400,
          "fit" => "zoom"
        })

      assert cfg["pattern"] == "blobs"
      assert cfg["opacity"] == 100
      assert cfg["fit"] == "stretch"
    end
  end

  describe "first_party_src/2" do
    test "allows same-origin paths and rejects hotlinks" do
      assert Themes.first_party_src("/images/qlink-themes/x.jpg", nil) ==
               "/images/qlink-themes/x.jpg"

      assert Themes.first_party_src("https://cdn.example/hot.jpg", nil) == nil
    end
  end

  describe "brand_logo_src/1" do
    test "uses first-party paths and rejects hotlinks" do
      page = %QlinkPage{brand_logo: "/images/qlink_logo_color_horiz.svg"}
      assert Themes.brand_logo_src(page) == "/images/qlink_logo_color_horiz.svg"

      assert Themes.brand_logo_src(%QlinkPage{brand_logo: "https://cdn.example/logo.png"}) == nil
      assert Themes.brand_logo_src(%QlinkPage{brand_logo: nil}) == nil
    end
  end

  describe "clamp_brand_logo_width/1" do
    test "defaults to 460 and caps at 460" do
      assert Themes.clamp_brand_logo_width(nil) == 460
      assert Themes.clamp_brand_logo_width(460) == 460
      assert Themes.clamp_brand_logo_width(999) == 460
      assert Themes.clamp_brand_logo_width(40) == 40
      assert Themes.clamp_brand_logo_width(20) == 40

      assert Themes.brand_logo_max_width(%QlinkPage{brand_logo_max_width: 200}) == 200
      assert Themes.brand_logo_max_width(%QlinkPage{brand_logo_max_width: 800}) == 460
    end
  end

  describe "css_vars/1" do
    test "emits custom properties for a template" do
      theme = Themes.resolve(Themes.apply("classic").theme_config)
      vars = Themes.css_vars(theme)
      assert vars =~ "--qlink-text:"
      assert vars =~ "--qlink-font:"
      assert vars =~ "--qlink-gutter:"
      assert vars =~ "--qlink-btn-border:"
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

  describe "parse_linear_gradient/1" do
    test "reads two-stop linear gradients" do
      parsed =
        Themes.parse_linear_gradient("linear-gradient(160deg, #ea580c 0%, #e11d48 100%)")

      assert parsed == %{"angle" => "160", "from" => "#ea580c", "to" => "#e11d48"}
    end

    test "returns nil for stacked radial blends" do
      aurora = Themes.apply("aurora").background_config["value"]
      assert Themes.parse_linear_gradient(aurora) == nil
    end
  end

  describe "merge_background/2" do
    test "seeds a linear gradient when switching from a solid color" do
      merged =
        Themes.merge_background(
          %{"type" => "solid", "value" => "#ffffff"},
          %{"type" => "gradient"}
        )

      assert merged["type"] == "gradient"
      assert merged["value"] == "linear-gradient(135deg, #ffffff 0%, #e11d48 100%)"
    end

    test "composes from/to/angle into CSS" do
      merged =
        Themes.merge_background(
          %{"type" => "gradient", "value" => "linear-gradient(160deg, #ea580c 0%, #e11d48 100%)"},
          %{"type" => "gradient", "from" => "#111111", "to" => "#eeeeee", "angle" => "90"}
        )

      assert merged == %{
               "type" => "gradient",
               "value" => "linear-gradient(90deg, #111111 0%, #eeeeee 100%)"
             }
    end

    test "keeps a custom blend when only type is posted" do
      aurora = Themes.apply("aurora").background_config

      assert Themes.merge_background(aurora, %{"type" => "gradient"}) == aurora
    end

    test "keeps image type while a file is still being chosen" do
      assert Themes.merge_background(%{"type" => "solid", "value" => "#0c0a09"}, %{
               "type" => "image"
             }) == %{"type" => "image"}
    end

    test "seeds a pattern from a solid color" do
      merged =
        Themes.merge_background(
          %{"type" => "solid", "value" => "#164e63"},
          %{"type" => "pattern"}
        )

      assert merged["type"] == "pattern"
      assert merged["pattern"] == "blobs"
      assert merged["base"] == "#164e63"
      assert merged["fill"] == "#ffffff"
      assert merged["opacity"] == 50
      assert merged["fit"] == "stretch"
    end
  end

  describe "background_css/1" do
    test "emits a data-uri SVG for pattern backgrounds" do
      page = %QlinkPage{
        background_config: %{
          "type" => "pattern",
          "pattern" => "stripes",
          "base" => "#95acd5",
          "fill" => "#ffffff",
          "opacity" => 50,
          "fit" => "tile"
        }
      }

      css = Themes.background_css(page)
      assert css =~ "background-color: #95acd5"
      assert css =~ "data:image/svg+xml;base64,"
      assert css =~ "background-repeat: repeat"
    end

    test "stretch fit uses 100% size" do
      page = %QlinkPage{
        background_config: %{
          "type" => "pattern",
          "pattern" => "blobs",
          "base" => "#95acd5",
          "fill" => "#ffffff",
          "opacity" => 50,
          "fit" => "stretch"
        }
      }

      css = Themes.background_css(page)
      assert css =~ "background-size: 100% 100%"
      assert css =~ "background-repeat: no-repeat"
    end
  end
end
