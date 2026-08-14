defmodule Qlarius.Qlink.BackgroundPatterns do
  @moduledoc """
  Curated SVG page patterns. Only first-party markup; fill/opacity are
  interpolated from already-sanitized hex and integer values.
  """

  @ids ~w(blobs stripes grid dots chevrons waves checks)
  @fits ~w(stretch tile)

  @blobs_d __DIR__
           |> Path.join("../../../priv/qlink/patterns/blobs.path")
           |> Path.expand()
           |> File.read!()
           |> String.trim()

  def ids, do: @ids
  def fits, do: @fits

  def options do
    [
      {"Blobs", "blobs"},
      {"Stripes", "stripes"},
      {"Grid", "grid"},
      {"Polka dots", "dots"},
      {"Chevrons", "chevrons"},
      {"Waves", "waves"},
      {"Checks", "checks"}
    ]
  end

  def css(%{
        "pattern" => id,
        "base" => base,
        "fill" => fill,
        "opacity" => opacity,
        "fit" => fit
      })
      when id in @ids do
    uri = svg_data_uri(id, fill, opacity)
    {size, repeat} = size_and_repeat(id, fit)

    "background-color: #{base}; background-image: #{uri}; background-size: #{size}; background-repeat: #{repeat}; background-position: center;"
  end

  def css(_), do: ""

  def swatch_css(id, base, fill, opacity) when id in @ids do
    css(%{
      "pattern" => id,
      "base" => base,
      "fill" => fill,
      "opacity" => opacity,
      "fit" => "tile"
    })
  end

  def swatch_css(_, _, _, _), do: ""

  defp size_and_repeat(_id, "stretch"), do: {"100% 100%", "no-repeat"}

  defp size_and_repeat(id, _tile) do
    {w, h} = tile_px(id)
    {"#{w}px #{h}px", "repeat"}
  end

  defp tile_px("blobs"), do: {180, 360}
  defp tile_px("chevrons"), do: {56, 28}
  defp tile_px("waves"), do: {80, 40}
  defp tile_px(_), do: {48, 48}

  defp svg_data_uri(id, fill, opacity) do
    svg = svg_markup(id, fill, opacity_attr(opacity))
    "url(\"data:image/svg+xml;base64,#{Base.encode64(svg)}\")"
  end

  defp opacity_attr(n) when is_integer(n), do: :erlang.float_to_binary(n / 100, decimals: 2)
  defp opacity_attr(_), do: "0.50"

  defp svg_markup("blobs", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 720" preserveAspectRatio="none"><path d="#{@blobs_d}" fill="#{fill}" fill-opacity="#{op}"/></svg>)
  end

  defp svg_markup("stripes", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" preserveAspectRatio="none"><path d="M-6 6L6 -6M0 24L24 0M18 30L30 18" fill="none" stroke="#{fill}" stroke-width="6" stroke-opacity="#{op}"/></svg>)
  end

  defp svg_markup("grid", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" preserveAspectRatio="none"><path d="M24 0H0V24" fill="none" stroke="#{fill}" stroke-width="1.5" stroke-opacity="#{op}"/></svg>)
  end

  defp svg_markup("dots", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" preserveAspectRatio="none"><circle cx="6" cy="6" r="3.2" fill="#{fill}" fill-opacity="#{op}"/><circle cx="18" cy="18" r="3.2" fill="#{fill}" fill-opacity="#{op}"/></svg>)
  end

  defp svg_markup("chevrons", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 20" preserveAspectRatio="none"><path d="M0 15L20 5L40 15" fill="none" stroke="#{fill}" stroke-width="4" stroke-linejoin="miter" stroke-opacity="#{op}"/></svg>)
  end

  defp svg_markup("waves", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 40" preserveAspectRatio="none"><path d="M0 20Q20 4 40 20T80 20" fill="none" stroke="#{fill}" stroke-width="4" stroke-opacity="#{op}"/></svg>)
  end

  defp svg_markup("checks", fill, op) do
    ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" preserveAspectRatio="none"><rect width="20" height="20" fill="#{fill}" fill-opacity="#{op}"/><rect x="20" y="20" width="20" height="20" fill="#{fill}" fill-opacity="#{op}"/></svg>)
  end
end
