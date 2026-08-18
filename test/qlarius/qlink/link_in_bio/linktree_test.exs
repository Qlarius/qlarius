defmodule Qlarius.Qlink.LinkInBio.LinktreeTest do
  use ExUnit.Case, async: true

  alias Qlarius.Qlink.LinkInBio.Linktree

  describe "parse/2" do
    test "builds GROUP sections first and nests child links by parent.id" do
      html =
        next_data(%{
          "props" => %{
            "pageProps" => %{
              "account" => %{
                "username" => "michsim",
                "pageTitle" => "MichSim",
                "description" => "Creator",
                "socialLinks" => [%{"url" => "https://instagram.com/michsim"}]
              },
              "links" => [
                group("1", 0, "The Optimization Edit"),
                group("2", 1, "Shop My Looks"),
                classic("10", "2", 1, "Amazon", "https://amazon.com/shop/michsim"),
                classic("11", "1", 1, "EgoHome", "https://egohome.com"),
                classic("12", "1", 0, "Bathhouse", "https://abathhouse.com")
              ]
            }
          }
        })

      draft = Linktree.parse(html, "https://linktr.ee/michsim")

      assert draft.platform == :linktree
      assert draft.suggested_alias == "michsim"
      assert draft.social_links["instagram"] == "https://instagram.com/michsim"

      assert Enum.map(draft.sections, & &1.title) == [
               "The Optimization Edit",
               "Shop My Looks"
             ]

      assert Enum.map(hd(draft.sections).links, & &1.title) == ["Bathhouse", "EgoHome"]
      assert Enum.map(List.last(draft.sections).links, & &1.title) == ["Amazon"]
    end

    test "groups sequential HEADER rows when links have no parent" do
      html =
        next_data(%{
          "props" => %{
            "pageProps" => %{
              "account" => %{"username" => "demo"},
              "links" => [
                %{"id" => "h1", "type" => "HEADER", "title" => "Shows", "position" => 0},
                classic("a", nil, 1, "Tickets", "https://example.com/tickets"),
                %{"id" => "h2", "type" => "HEADER", "title" => "Shop", "position" => 2},
                classic("b", nil, 3, "Merch", "https://example.com/merch")
              ]
            }
          }
        })

      draft = Linktree.parse(html, "https://linktr.ee/demo")

      assert Enum.map(draft.sections, & &1.title) == ["Shows", "Shop"]
      assert hd(draft.sections).links |> Enum.map(& &1.title) == ["Tickets"]
      assert List.last(draft.sections).links |> Enum.map(& &1.title) == ["Merch"]
    end

    test "keeps unsectioned links in an untitled section" do
      html =
        next_data(%{
          "props" => %{
            "pageProps" => %{
              "account" => %{"username" => "flat"},
              "links" => [
                classic("a", nil, 0, "One", "https://example.com/one"),
                classic("b", nil, 1, "Two", "https://example.com/two")
              ]
            }
          }
        })

      draft = Linktree.parse(html, "https://linktr.ee/flat")

      assert [%{title: nil, links: links}] = draft.sections
      assert Enum.map(links, & &1.title) == ["One", "Two"]
    end
  end

  defp group(id, position, title) do
    %{
      "id" => id,
      "type" => "GROUP",
      "title" => title,
      "position" => position,
      "parent" => nil,
      "url" => nil
    }
  end

  defp classic(id, parent_id, position, title, url) do
    parent =
      if parent_id do
        %{"id" => parent_id}
      else
        nil
      end

    %{
      "id" => id,
      "type" => "CLASSIC",
      "title" => title,
      "url" => url,
      "position" => position,
      "parent" => parent
    }
  end

  defp next_data(payload) do
    json = Jason.encode!(payload)
    ~s(<html><head></head><body><script id="__NEXT_DATA__" type="application/json">#{json}</script></body></html>)
  end
end
