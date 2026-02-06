defmodule QlariusWeb.ManifestController do
  use QlariusWeb, :controller

  @manifest %{
    "id" => "/",
    "name" => "Qadabra",
    "short_name" => "Qadabra",
    "scope" => "/",
    "display" => "standalone",
    "background_color" => "#1f2937",
    "theme_color" => "#1f2937",
    "orientation" => "portrait",
    "icons" => [
      %{
        "src" => "/images/qlarius_app_icon_180.png",
        "sizes" => "180x180",
        "type" => "image/png",
        "purpose" => "any"
      },
      %{
        "src" => "/images/qadabra_app_icon_192.png",
        "sizes" => "192x192",
        "type" => "image/png",
        "purpose" => "any maskable"
      },
      %{
        "src" => "/images/qadabra_app_icon_512.png",
        "sizes" => "512x512",
        "type" => "image/png",
        "purpose" => "any maskable"
      }
    ]
  }

  def show(conn, params) do
    ref_code = params["ref"]

    start_url =
      if ref_code && ref_code != "" do
        "/?ref=#{ref_code}"
      else
        "/"
      end

    manifest = Map.put(@manifest, "start_url", start_url)

    conn
    |> put_resp_content_type("application/manifest+json")
    |> json(manifest)
  end
end
