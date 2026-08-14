defmodule Qlarius.Qlink.Themes do
  @moduledoc """
  Curated Qlink page templates and resolved design tokens.

  Theme switching is LiveView-rendered: Elixir writes CSS variables and
  modifier classes. No JS hooks or stylesheet swaps.
  """

  alias Qlarius.Qlink.BackgroundPatterns
  alias Qlarius.Qlink.QlinkPage
  alias QlariusWeb.Uploaders.CreatorImage

  @template_ids ~w(classic midnight sunset aurora editorial bloom neon forest brutalist coastal)

  @fonts %{
    "figtree" => {"Figtree", "sans-serif"},
    "outfit" => {"Outfit", "sans-serif"},
    "syne" => {"Syne", "sans-serif"},
    "fraunces" => {"Fraunces", "serif"},
    "nunito" => {"Nunito", "sans-serif"},
    "ibm_plex_mono" => {"IBM Plex Mono", "monospace"},
    "newsreader" => {"Newsreader", "serif"},
    "bricolage" => {"Bricolage Grotesque", "sans-serif"},
    "karla" => {"Karla", "sans-serif"}
  }

  @layouts ~w(classic media cover stack)
  @shapes ~w(pill rounded square)
  @styles ~w(fill outline shadow glass)
  @headers ~w(avatar hero)
  @avatars ~w(circle rounded)
  @embed_themes ~w(light dark)
  @brand_logo_width_min 40
  @brand_logo_width_max 460

  @hex ~r/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
  @gradient_ok ~r/^(?:repeating-)?(?:linear|radial|conic)-gradient\(/i
  @linear_two ~r/^linear-gradient\(\s*(\d+(?:\.\d+)?)deg\s*,\s*(#[0-9a-fA-F]{3,8})(?:\s+\d+%)?\s*,\s*(#[0-9a-fA-F]{3,8})/i

  @gradient_angles [
    {"Up", "0"},
    {"Up right", "45"},
    {"Right", "90"},
    {"Down right", "135"},
    {"Down", "180"}
  ]

  @shape_radius %{
    "pill" => "9999px",
    "rounded" => "1rem",
    "square" => "0.25rem"
  }

  def template_ids, do: @template_ids
  def layouts, do: @layouts
  def shapes, do: @shapes
  def styles, do: @styles
  def headers, do: @headers
  def avatars, do: @avatars
  def embed_themes, do: @embed_themes
  def gradient_angles, do: @gradient_angles
  def pattern_ids, do: BackgroundPatterns.ids()
  def pattern_options, do: BackgroundPatterns.options()
  def pattern_fits, do: BackgroundPatterns.fits()

  def font_options do
    Enum.map(@fonts, fn {id, {name, _}} -> {name, id} end)
  end

  def font_family(id) do
    case Map.get(@fonts, id) do
      {name, fallback} -> "#{inspect(name)}, #{fallback}"
      nil -> "ui-sans-serif, system-ui, sans-serif"
    end
  end

  def templates do
    Enum.map(@template_ids, fn id ->
      t = template(id)
      Map.put(t, "id", id)
    end)
  end

  def template(id) when id in @template_ids, do: templates_by_id()[id]
  def template(_), do: nil

  @doc """
  Full theme + background maps for a template id. Re-applying overwrites
  tokens only — callers must not touch links/content.
  """
  def apply(id) do
    case template(id) do
      nil ->
        nil

      t ->
        %{
          theme_config: Map.delete(t, "background"),
          background_config: t["background"]
        }
    end
  end

  @doc """
  Whether the current theme and background still match their origin template.

  * `:none` — no template
  * `{:applied, id, label}` — tokens match the template
  * `{:custom, id, label}` — template was a starting point but styling has diverged
  """
  def template_origin(theme_config, background_config) do
    theme = sanitize_theme_config(theme_config)
    id = theme["template_id"]

    case template(id) do
      %{"label" => label} ->
        if matches_template?(theme, background_config, id) do
          {:applied, id, label}
        else
          {:custom, id, label}
        end

      _ ->
        :none
    end
  end

  def template_summary(:none), do: "None"

  def template_summary({:applied, _id, label}), do: label

  def template_summary({:custom, _id, label}), do: "Custom (from #{label} originally)"

  defp matches_template?(theme, background_config, id) do
    %{theme_config: applied_theme, background_config: applied_bg} = apply(id)

    theme == sanitize_theme_config(applied_theme) and
      sanitize_background_config(background_config) == sanitize_background_config(applied_bg)
  end

  @doc """
  Returns a sanitized theme map, or nil for unthemed/legacy pages.
  """
  def resolve(%QlinkPage{theme_config: cfg}), do: resolve(cfg)
  def resolve(nil), do: nil
  def resolve(cfg) when cfg == %{}, do: nil

  def resolve(cfg) when is_map(cfg) do
    sanitized = sanitize_theme_config(cfg)

    if sanitized == %{} do
      nil
    else
      Map.put(sanitized, "themed?", true)
    end
  end

  def resolve(_), do: nil

  def themed?(%{"themed?" => true}), do: true
  def themed?(_), do: false

  def css_vars(nil), do: ""

  def css_vars(theme) when is_map(theme) do
    button = theme["button"] || %{}
    shape = button["shape"] || "pill"

    custom =
      [
        {"--qlink-text", theme["text_color"]},
        {"--qlink-canvas", theme["canvas"]},
        {"--qlink-gutter", theme["gutter"]},
        {"--qlink-font", font_family(theme["font"])},
        {"--qlink-btn-bg", button["bg"]},
        {"--qlink-btn-text", button["text"]},
        {"--qlink-btn-border", button["border"]},
        {"--qlink-btn-radius", Map.get(@shape_radius, shape, "9999px")}
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join("; ")

    extras =
      if themed?(theme) do
        "color: var(--qlink-text); font-family: var(--qlink-font);"
      else
        ""
      end

    [custom, extras]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  def page_classes(nil), do: ["qlink-public-page--stage"]

  def page_classes(theme) when is_map(theme) do
    style = get_in(theme, ["button", "style"])
    shape = get_in(theme, ["button", "shape"])

    ["qlink-public-page--stage"]
    |> then(fn cls -> if themed?(theme), do: ["qlink-public-page--themed" | cls], else: cls end)
    |> then(fn cls -> if theme["grain"], do: ["qlink-public-page--grain" | cls], else: cls end)
    |> then(fn cls ->
      if themed?(theme) and style in @styles,
        do: ["qlink-public-page--btn-#{style}" | cls],
        else: cls
    end)
    |> then(fn cls ->
      if themed?(theme) and shape in @shapes,
        do: ["qlink-public-page--shape-#{shape}" | cls],
        else: cls
    end)
  end

  def header_mode(theme, page) do
    photo? = is_binary(page && page.profile_photo) and page.profile_photo != ""

    if themed?(theme) and theme["header"] == "hero" and photo? do
      "hero"
    else
      "avatar"
    end
  end

  def button_layout(theme, thumbnail?) do
    layout = get_in(theme || %{}, ["button", "layout"]) || "classic"

    if thumbnail? and layout in @layouts do
      layout
    else
      "classic"
    end
  end

  def embed_theme(nil), do: nil

  def embed_theme(theme) when is_map(theme) do
    case theme["embed_theme"] do
      t when t in @embed_themes -> t
      _ -> nil
    end
  end

  @doc """
  Daisy theme for `<html>` on a public Qlink page.

  Set from `QlinkPage.Show` mount (not the request host), so every
  surface that renders this LiveView — qlinkin.bio, qlink.qadabra.app,
  and localhost — pins the same way. Unthemed pages pin to light.
  """
  def document_theme(theme) do
    embed_theme(theme) || "light"
  end

  @doc """
  Safe inline background CSS. Never interpolates third-party URLs.
  """
  def background_css(%QlinkPage{} = page) do
    case sanitize_background_config(page.background_config) do
      %{"type" => "solid", "value" => color} ->
        "background-color: #{color};"

      %{"type" => "gradient", "value" => gradient} ->
        "background: #{gradient};"

      %{"type" => "image", "file" => file} ->
        image_background_css(first_party_src(file, page))

      %{"type" => "image", "static" => path} ->
        image_background_css(first_party_src(path, page))

      %{"type" => "pattern"} = cfg ->
        BackgroundPatterns.css(cfg)

      _ ->
        ""
    end
  end

  def background_css(_), do: ""

  @doc """
  Two-stop `linear-gradient(Ndeg, #from, #to)` as picker fields, or nil
  for custom blends (Aurora-style stacked radials).
  """
  def parse_linear_gradient(value) when is_binary(value) do
    case Regex.run(@linear_two, String.trim(value)) do
      [_, angle, from, to] ->
        from = expand_hex(from)
        to = expand_hex(to)

        if from && to do
          %{"angle" => normalize_angle(angle) || "135", "from" => from, "to" => to}
        else
          nil
        end

      _ ->
        nil
    end
  end

  def parse_linear_gradient(_), do: nil

  def compose_linear_gradient(angle, from, to) do
    deg = normalize_angle(angle) || "135"
    "linear-gradient(#{deg}deg, #{from} 0%, #{to} 100%)"
  end

  defp image_background_css(nil), do: ""

  defp image_background_css(src) do
    case escape_css_url(src) do
      nil ->
        ""

      safe ->
        "background-image: url('#{safe}'); background-size: cover; background-position: center;"
    end
  end

  @doc """
  Resolve a chrome image to a first-party URL, or nil (fail closed).
  """
  def first_party_src(nil, _page), do: nil
  def first_party_src("", _page), do: nil

  def first_party_src(value, %QlinkPage{} = page) when is_binary(value) do
    cond do
      String.starts_with?(value, ["/uploads/", "/images/"]) ->
        value

      http_url?(value) ->
        if first_party_url?(value), do: value, else: nil

      looks_like_filename?(value) ->
        case CreatorImage.url({value, page}, :original) do
          url when is_binary(url) and url != "" ->
            if http_url?(url) and not first_party_url?(url), do: nil, else: url

          _ ->
            nil
        end

      true ->
        nil
    end
  end

  def first_party_src(path, _page) when is_binary(path) do
    cond do
      String.starts_with?(path, ["/uploads/", "/images/"]) ->
        path

      http_url?(path) ->
        if first_party_url?(path), do: path, else: nil

      true ->
        nil
    end
  end

  def first_party_src(_, _), do: nil

  @doc """
  First-party URL for a page brand logo, or nil.
  """
  def brand_logo_src(%QlinkPage{} = page), do: first_party_src(page.brand_logo, page)
  def brand_logo_src(_), do: nil

  def brand_logo_width_min, do: @brand_logo_width_min
  def brand_logo_width_max, do: @brand_logo_width_max

  def brand_logo_max_width(%QlinkPage{} = page),
    do: clamp_brand_logo_width(page.brand_logo_max_width)

  def brand_logo_max_width(_), do: @brand_logo_width_max

  def clamp_brand_logo_width(n) when is_integer(n) do
    n |> max(@brand_logo_width_min) |> min(@brand_logo_width_max)
  end

  def clamp_brand_logo_width(_), do: @brand_logo_width_max

  def first_party_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        allowed_host?(host)

      _ ->
        false
    end
  end

  def first_party_url?(_), do: false

  def sanitize_theme_config(nil), do: %{}

  def sanitize_theme_config(cfg) when is_map(cfg) do
    cfg = stringify_keys(cfg)

    if cfg == %{} do
      %{}
    else
      base = template_defaults(cfg["template_id"])
      merged = merge_theme(base, cfg)
      button = stringify_keys(merged["button"] || %{})
      base_button = stringify_keys(base["button"] || %{})

      grain =
        if Map.has_key?(cfg, "grain"), do: truthy?(cfg["grain"]), else: truthy?(merged["grain"])

      %{
        "template_id" => pick(merged["template_id"], @template_ids, nil),
        "text_color" => hex_or(merged["text_color"], hex_or(base["text_color"], "#0c0a09")),
        "canvas" => hex_or(merged["canvas"], hex_or(base["canvas"], "#ffffff")),
        "gutter" => hex_or(merged["gutter"], hex_or(base["gutter"], nil)),
        "font" =>
          pick(merged["font"], Map.keys(@fonts), pick(base["font"], Map.keys(@fonts), "figtree")),
        "button" => %{
          "layout" =>
            pick(button["layout"], @layouts, pick(base_button["layout"], @layouts, "classic")),
          "shape" => pick(button["shape"], @shapes, pick(base_button["shape"], @shapes, "pill")),
          "style" => pick(button["style"], @styles, pick(base_button["style"], @styles, "fill")),
          "bg" => hex_or(button["bg"], hex_or(base_button["bg"], "#0c0a09")),
          "text" => hex_or(button["text"], hex_or(base_button["text"], "#fafaf9")),
          "border" =>
            hex_or(
              button["border"],
              hex_or(
                base_button["border"],
                hex_or(button["text"], hex_or(base_button["text"], "#fafaf9"))
              )
            )
        },
        "avatar" => pick(merged["avatar"], @avatars, pick(base["avatar"], @avatars, "circle")),
        "header" => pick(merged["header"], @headers, pick(base["header"], @headers, "avatar")),
        "grain" => grain,
        "embed_theme" =>
          pick(
            merged["embed_theme"],
            @embed_themes,
            pick(base["embed_theme"], @embed_themes, "light")
          )
      }
      |> then(fn theme ->
        if theme["gutter"], do: theme, else: Map.delete(theme, "gutter")
      end)
    end
  end

  def sanitize_theme_config(_), do: %{}

  def sanitize_background_config(nil), do: %{}

  def sanitize_background_config(cfg) when is_map(cfg) do
    cfg = stringify_keys(cfg)

    case cfg["type"] do
      "solid" ->
        case hex_or(cfg["value"], nil) do
          nil -> %{}
          color -> %{"type" => "solid", "value" => color}
        end

      "gradient" ->
        if safe_gradient?(cfg["value"]) do
          %{"type" => "gradient", "value" => String.trim(cfg["value"])}
        else
          %{}
        end

      "image" ->
        cond do
          is_binary(cfg["file"]) and cfg["file"] != "" and not http_url?(cfg["file"]) ->
            %{"type" => "image", "file" => cfg["file"]}

          is_binary(cfg["static"]) and String.starts_with?(cfg["static"], "/images/") ->
            %{"type" => "image", "static" => cfg["static"]}

          true ->
            %{"type" => "image"}
        end

      "pattern" ->
        sanitize_pattern_config(cfg)

      _ ->
        %{}
    end
  end

  def sanitize_background_config(_), do: %{}

  def merge_theme(current, incoming) do
    current = stringify_keys(current || %{})
    incoming = stringify_keys(incoming || %{})
    button = Map.merge(current["button"] || %{}, incoming["button"] || %{})

    current
    |> Map.merge(incoming)
    |> Map.put("button", button)
  end

  def merge_background(current, incoming) do
    current = stringify_keys(current || %{})
    incoming = stringify_keys(incoming || %{})
    merged = Map.merge(current, incoming)

    case merged["type"] do
      "solid" ->
        color =
          hex_or(incoming["value"], nil) ||
            hex_or(current["value"], nil) ||
            get_in(parse_linear_gradient(current["value"]) || %{}, ["from"]) ||
            "#ffffff"

        %{"type" => "solid", "value" => color}

      "gradient" ->
        %{"type" => "gradient", "value" => gradient_value_from_merge(current, incoming)}

      "image" ->
        cond do
          is_binary(merged["file"]) and merged["file"] != "" and not http_url?(merged["file"]) ->
            %{"type" => "image", "file" => merged["file"]}

          is_binary(current["file"]) and current["file"] != "" and not http_url?(current["file"]) ->
            %{"type" => "image", "file" => current["file"]}

          is_binary(merged["static"]) and String.starts_with?(merged["static"], "/images/") ->
            %{"type" => "image", "static" => merged["static"]}

          true ->
            %{"type" => "image"}
        end

      "pattern" ->
        sanitize_pattern_config(%{
          "pattern" => merged["pattern"],
          "base" =>
            incoming["base"] ||
              current["base"] ||
              incoming["value"] ||
              current["value"] ||
              get_in(parse_linear_gradient(current["value"]) || %{}, ["from"]),
          "fill" => incoming["fill"] || current["fill"],
          "opacity" => incoming["opacity"] || current["opacity"],
          "fit" => incoming["fit"] || current["fit"]
        })

      _ ->
        %{}
    end
  end

  defp sanitize_pattern_config(cfg) do
    %{
      "type" => "pattern",
      "pattern" => pick(cfg["pattern"], BackgroundPatterns.ids(), "blobs"),
      "base" => hex_or(cfg["base"], "#95acd5"),
      "fill" => hex_or(cfg["fill"], "#ffffff"),
      "opacity" => clamp_opacity(cfg["opacity"]),
      "fit" => pick(cfg["fit"], BackgroundPatterns.fits(), "stretch")
    }
  end

  defp clamp_opacity(value) do
    n =
      cond do
        is_integer(value) ->
          value

        is_float(value) ->
          if value <= 1.0, do: round(value * 100), else: round(value)

        is_binary(value) ->
          case Integer.parse(value) do
            {int, _} -> int
            :error -> 50
          end

        true ->
          50
      end

    n |> max(10) |> min(100)
  end

  defp gradient_value_from_merge(current, incoming) do
    from = hex_or(incoming["from"], nil)
    to = hex_or(incoming["to"], nil)

    angle =
      normalize_angle(incoming["angle"]) ||
        get_in(parse_linear_gradient(current["value"]) || %{}, ["angle"]) ||
        "135"

    cond do
      from && to ->
        compose_linear_gradient(angle, from, to)

      safe_gradient?(incoming["value"]) ->
        String.trim(incoming["value"])

      safe_gradient?(current["value"]) ->
        String.trim(current["value"])

      true ->
        seed = hex_or(current["value"], "#ea580c")
        compose_linear_gradient("135", seed, "#e11d48")
    end
  end

  defp normalize_angle(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} when n in 0..360 -> Integer.to_string(n)
      _ -> nil
    end
  end

  defp normalize_angle(n) when is_integer(n) and n in 0..360, do: Integer.to_string(n)
  defp normalize_angle(_), do: nil

  defp expand_hex("#" <> hex) do
    hex = String.downcase(hex)

    expanded =
      case String.length(hex) do
        3 -> hex |> String.graphemes() |> Enum.map_join(&(&1 <> &1))
        6 -> hex
        8 -> String.slice(hex, 0, 6)
        _ -> nil
      end

    if expanded, do: hex_or("#" <> expanded, nil)
  end

  defp expand_hex(_), do: nil

  defp template_defaults(id) do
    case template(id) do
      nil ->
        %{}

      t ->
        Map.drop(t, ["background", "label", "swatch"])
    end
  end

  defp templates_by_id do
    %{
      "classic" => %{
        "template_id" => "classic",
        "text_color" => "#0c0a09",
        "canvas" => "#ffffff",
        "gutter" => "#c5c9d0",
        "font" => "figtree",
        "button" => %{
          "layout" => "classic",
          "shape" => "pill",
          "style" => "fill",
          "bg" => "#0c0a09",
          "text" => "#fafaf9",
          "border" => "#fafaf9"
        },
        "avatar" => "circle",
        "header" => "avatar",
        "grain" => false,
        "embed_theme" => "light",
        "background" => %{"type" => "solid", "value" => "#ffffff"},
        "label" => "Classic",
        "swatch" => "#ffffff"
      },
      "midnight" => %{
        "template_id" => "midnight",
        "text_color" => "#f5f5f4",
        "canvas" => "#0c0a09",
        "gutter" => "#292524",
        "font" => "outfit",
        "button" => %{
          "layout" => "classic",
          "shape" => "pill",
          "style" => "outline",
          "bg" => "#1c1917",
          "text" => "#f5f5f4",
          "border" => "#f5f5f4"
        },
        "avatar" => "circle",
        "header" => "avatar",
        "grain" => false,
        "embed_theme" => "dark",
        "background" => %{"type" => "solid", "value" => "#0c0a09"},
        "label" => "Midnight",
        "swatch" => "#0c0a09"
      },
      "sunset" => %{
        "template_id" => "sunset",
        "text_color" => "#fff7ed",
        "canvas" => "#9f1239",
        "gutter" => "#4c0519",
        "font" => "syne",
        "button" => %{
          "layout" => "cover",
          "shape" => "rounded",
          "style" => "fill",
          "bg" => "#fff7ed",
          "text" => "#9f1239",
          "border" => "#9f1239"
        },
        "avatar" => "circle",
        "header" => "hero",
        "grain" => false,
        "embed_theme" => "dark",
        "background" => %{
          "type" => "gradient",
          "value" => "linear-gradient(160deg, #ea580c 0%, #e11d48 100%)"
        },
        "label" => "Sunset",
        "swatch" => "#ea580c"
      },
      "aurora" => %{
        "template_id" => "aurora",
        "text_color" => "#e0f2fe",
        "canvas" => "#0f172a",
        "gutter" => "#020617",
        "font" => "outfit",
        "button" => %{
          "layout" => "classic",
          "shape" => "rounded",
          "style" => "glass",
          "bg" => "#1e293b",
          "text" => "#e0f2fe",
          "border" => "#e0f2fe"
        },
        "avatar" => "circle",
        "header" => "avatar",
        "grain" => true,
        "embed_theme" => "dark",
        "background" => %{
          "type" => "gradient",
          "value" =>
            "radial-gradient(at 20% 15%, #22d3ee 0px, transparent 50%), radial-gradient(at 80% 10%, #a78bfa 0px, transparent 45%), radial-gradient(at 50% 90%, #34d399 0px, transparent 50%), #0f172a"
        },
        "label" => "Aurora",
        "swatch" => "#22d3ee"
      },
      "editorial" => %{
        "template_id" => "editorial",
        "text_color" => "#1c1917",
        "canvas" => "#faf6ee",
        "gutter" => "#d6d3d1",
        "font" => "fraunces",
        "button" => %{
          "layout" => "media",
          "shape" => "rounded",
          "style" => "shadow",
          "bg" => "#ffffff",
          "text" => "#1c1917",
          "border" => "#1c1917"
        },
        "avatar" => "rounded",
        "header" => "hero",
        "grain" => false,
        "embed_theme" => "light",
        "background" => %{"type" => "solid", "value" => "#faf6ee"},
        "label" => "Editorial",
        "swatch" => "#faf6ee"
      },
      "bloom" => %{
        "template_id" => "bloom",
        "text_color" => "#831843",
        "canvas" => "#fdf2f8",
        "gutter" => "#f9a8d4",
        "font" => "nunito",
        "button" => %{
          "layout" => "media",
          "shape" => "pill",
          "style" => "fill",
          "bg" => "#fce7f3",
          "text" => "#831843",
          "border" => "#831843"
        },
        "avatar" => "circle",
        "header" => "hero",
        "grain" => false,
        "embed_theme" => "light",
        "background" => %{"type" => "solid", "value" => "#fdf2f8"},
        "label" => "Bloom",
        "swatch" => "#fdf2f8"
      },
      "neon" => %{
        "template_id" => "neon",
        "text_color" => "#d9f99d",
        "canvas" => "#052e16",
        "gutter" => "#022c22",
        "font" => "ibm_plex_mono",
        "button" => %{
          "layout" => "classic",
          "shape" => "square",
          "style" => "outline",
          "bg" => "#14532d",
          "text" => "#d9f99d",
          "border" => "#d9f99d"
        },
        "avatar" => "rounded",
        "header" => "avatar",
        "grain" => false,
        "embed_theme" => "dark",
        "background" => %{"type" => "solid", "value" => "#052e16"},
        "label" => "Neon",
        "swatch" => "#052e16"
      },
      "forest" => %{
        "template_id" => "forest",
        "text_color" => "#ecfdf5",
        "canvas" => "#14532d",
        "gutter" => "#052e16",
        "font" => "newsreader",
        "button" => %{
          "layout" => "stack",
          "shape" => "rounded",
          "style" => "fill",
          "bg" => "#052e16",
          "text" => "#ecfdf5",
          "border" => "#ecfdf5"
        },
        "avatar" => "rounded",
        "header" => "hero",
        "grain" => true,
        "embed_theme" => "dark",
        "background" => %{"type" => "solid", "value" => "#14532d"},
        "label" => "Forest",
        "swatch" => "#14532d"
      },
      "brutalist" => %{
        "template_id" => "brutalist",
        "text_color" => "#171717",
        "canvas" => "#fafafa",
        "gutter" => "#737373",
        "font" => "bricolage",
        "button" => %{
          "layout" => "classic",
          "shape" => "square",
          "style" => "shadow",
          "bg" => "#fafafa",
          "text" => "#171717",
          "border" => "#171717"
        },
        "avatar" => "rounded",
        "header" => "avatar",
        "grain" => false,
        "embed_theme" => "light",
        "background" => %{"type" => "solid", "value" => "#fafafa"},
        "label" => "Brutalist",
        "swatch" => "#fafafa"
      },
      "coastal" => %{
        "template_id" => "coastal",
        "text_color" => "#164e63",
        "canvas" => "#ecfeff",
        "gutter" => "#0e7490",
        "font" => "karla",
        "button" => %{
          "layout" => "media",
          "shape" => "rounded",
          "style" => "fill",
          "bg" => "#cffafe",
          "text" => "#164e63",
          "border" => "#164e63"
        },
        "avatar" => "circle",
        "header" => "hero",
        "grain" => false,
        "embed_theme" => "light",
        "background" => %{"type" => "solid", "value" => "#ecfeff"},
        "label" => "Coastal",
        "swatch" => "#ecfeff"
      }
    }
  end

  defp allowed_host?(host) do
    asset_host = waffle_asset_host()

    host == "localhost" or host == "127.0.0.1" or
      host == "qadabra.app" or String.ends_with?(host, ".qadabra.app") or
      host == "qlinkin.bio" or String.ends_with?(host, ".qlinkin.bio") or
      String.ends_with?(host, ".amazonaws.com") or
      String.ends_with?(host, ".gigalixirapp.com") or
      (is_binary(asset_host) and (host == asset_host or String.ends_with?(asset_host, host)))
  end

  defp waffle_asset_host do
    case Application.get_env(:waffle, :asset_host) do
      host when is_binary(host) ->
        case URI.parse(host) do
          %URI{host: h} when is_binary(h) -> h
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp http_url?(value) when is_binary(value) do
    String.starts_with?(value, ["http://", "https://"])
  end

  defp http_url?(_), do: false

  defp looks_like_filename?(value) do
    ext = value |> Path.extname() |> String.downcase()
    ext in ~w(.jpg .jpeg .png .gif .webp)
  end

  defp escape_css_url(url) when is_binary(url) do
    if String.contains?(url, ["'", "\"", "(", ")", "\\", "\n", "\r", "<", ">"]) do
      nil
    else
      url
    end
  end

  defp escape_css_url(_), do: nil

  defp safe_gradient?(value) when is_binary(value) do
    trimmed = String.trim(value)
    lower = String.downcase(trimmed)

    String.match?(trimmed, @gradient_ok) and
      String.length(trimmed) < 600 and
      not String.contains?(lower, ["url(", "expression", "javascript", "@import", "<"])
  end

  defp safe_gradient?(_), do: false

  defp hex_or(value, fallback) when is_binary(value) do
    trimmed = String.trim(value)
    if String.match?(trimmed, @hex), do: trimmed, else: fallback
  end

  defp hex_or(_, fallback), do: fallback

  defp pick(value, allowed, fallback) when is_binary(value) do
    if value in allowed, do: value, else: fallback
  end

  defp pick(_, _allowed, fallback), do: fallback

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
  end

  defp stringify_keys(other), do: other
end
