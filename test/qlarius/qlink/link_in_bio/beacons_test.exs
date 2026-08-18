defmodule Qlarius.Qlink.LinkInBio.BeaconsTest do
  use ExUnit.Case, async: true

  alias Qlarius.Qlink.LinkInBio.Beacons

  test "opens a section for each header then places following links in it" do
    html =
      next_data(%{
        "props" => %{
          "pageProps" => %{
            "profile" => %{"username" => "beacon", "displayName" => "Beacon"},
            "blocks" => [
              %{"type" => "header", "title" => "Listen"},
              %{
                "type" => "link",
                "title" => "Spotify",
                "url" => "https://example.com/spotify"
              },
              %{"type" => "header", "title" => "Watch", "description" => "Latest videos"},
              %{
                "type" => "button",
                "title" => "YouTube",
                "url" => "https://example.com/watch"
              }
            ]
          }
        }
      })

    draft = Beacons.parse(html, "https://beacons.ai/beacon")

    assert Enum.map(draft.sections, & &1.title) == ["Listen", "Watch"]
    assert hd(draft.sections).links |> Enum.map(& &1.title) == ["Spotify"]
    assert List.last(draft.sections).description == "Latest videos"
    assert List.last(draft.sections).links |> Enum.map(& &1.title) == ["YouTube"]
  end

  defp next_data(payload) do
    json = Jason.encode!(payload)
    ~s(<html><script id="__NEXT_DATA__" type="application/json">#{json}</script></html>)
  end
end
