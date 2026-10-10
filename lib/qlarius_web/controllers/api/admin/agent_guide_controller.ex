defmodule QlariusWeb.Api.Admin.AgentGuideController do
  @moduledoc """
  Serves the written how-to an AI agent reads before calling the admin API.
  """

  use QlariusWeb, :controller

  alias QlariusWeb.Api.Admin.Responder

  @version "2026-10-10.2"
  @guides_dir Path.expand("../../../../../priv/agent_guides", __DIR__)
  @topics ~w(overview content_groups traits ad_categories campaigns)

  for topic <- @topics do
    @external_resource Path.join(@guides_dir, "#{topic}.md")
  end

  @guides Map.new(@topics, fn topic ->
            {topic, File.read!(Path.join(@guides_dir, "#{topic}.md"))}
          end)

  @endpoints [
    %{method: "GET", path: "/api/admin/agent_guide", purpose: "This guide"},
    %{method: "GET", path: "/api/admin/creators", purpose: "Creators and their catalogs"},
    %{
      method: "GET",
      path: "/api/admin/content_groups?catalog_id=",
      purpose: "Content groups in a catalog"
    },
    %{
      method: "GET",
      path: "/api/admin/rss/preview?feed_url=",
      purpose: "Read a podcast feed: channel, seasons, items"
    },
    %{
      method: "POST",
      path: "/api/admin/content_groups/rss_imports",
      purpose: "Import a feed (or one season of it) as a content group"
    },
    %{
      method: "POST",
      path: "/api/admin/content_groups/packs",
      purpose: "Create or update a content group from an agent-built pack"
    },
    %{
      method: "POST",
      path: "/api/admin/content_groups/:id/sync",
      purpose:
        "Re-read a group's stored feed and add new episodes; body {\"reorder\": true} also puts the group in episode order"
    },
    %{
      method: "POST",
      path: "/api/admin/traits/design_packs",
      purpose: "Create or reform a parent trait with children and survey"
    },
    %{
      method: "GET",
      path: "/api/admin/trait_search?q=&scope=builder|all",
      purpose: "Ranked trait search as the Builder (builder, top 15) or Qai (all, top 10) sees it"
    },
    %{
      method: "GET",
      path: "/api/admin/ad_categories?q=&category_id=&cohort=&active=",
      purpose: "Ad taxonomy rows grouped by category, with media piece counts"
    },
    %{
      method: "POST",
      path: "/api/admin/ad_categories/import",
      purpose: "Upsert taxonomy rows on row_id (dry_run supported)"
    },
    %{
      method: "POST",
      path: "/api/admin/ad_categories/remap",
      purpose: "Move media pieces from one row to another (dry_run supported)"
    },
    %{
      method: "POST",
      path: "/api/admin/ad_categories/prune",
      purpose: "Delete rows no media piece uses (dry_run supported)"
    },
    %{
      method: "GET",
      path: "/api/admin/media_piece_types",
      purpose: "Ad types with pricing, required fields, and whether the API can create them"
    },
    %{
      method: "GET",
      path: "/api/admin/media_pieces?marketer_id=&row_id=&active=&q=&api_ref_prefix=",
      purpose: "Ads, filtered by marketer, ad category row, and api_ref prefix"
    },
    %{
      method: "POST",
      path: "/api/admin/media_pieces",
      purpose: "Create an ad with an HTTPS image_url or multipart banner (dry_run supported)"
    },
    %{
      method: "PATCH",
      path: "/api/admin/media_pieces/:id",
      purpose: "Edit an ad (dry_run supported)"
    },
    %{
      method: "DELETE",
      path: "/api/admin/media_pieces/:id",
      purpose: "Delete an ad that no run or ad event uses (dry_run supported)"
    },
    %{
      method: "GET",
      path: "/api/admin/marketers?q=&domain=&api_ref_prefix=&has_ptp=",
      purpose: "Marketers with counts of campaigns, ads, targets, groups, sequences, members"
    },
    %{
      method: "POST",
      path: "/api/admin/marketers",
      purpose:
        "Find-or-create a marketer by api_ref (required); dry_run and on_existing supported"
    },
    %{
      method: "PATCH",
      path: "/api/admin/marketers/:id",
      purpose: "Edit a marketer (dry_run supported)"
    },
    %{
      method: "DELETE",
      path: "/api/admin/marketers/:id",
      purpose: "Delete a marketer with no dependents (dry_run supported)"
    },
    %{
      method: "POST",
      path: "/api/admin/trait_groups",
      purpose: "Create a trait group from existing traits (dry_run supported)"
    },
    %{
      method: "GET",
      path: "/api/admin/zip_codes?q=",
      purpose:
        "Search zip traits under Home Zip Code, or parent_trait_id. q must be at least 2 characters"
    },
    %{
      method: "POST",
      path: "/api/admin/targets/builds",
      purpose: "Build a target bullseye outward from existing trait groups"
    },
    %{
      method: "POST",
      path: "/api/admin/media_sequences",
      purpose: "Create a sequence and its one run, filling PTP frequency defaults"
    },
    %{
      method: "POST",
      path: "/api/admin/campaigns",
      purpose: "Create a draft campaign with bids. Launch is a separate confirm call"
    },
    %{
      method: "POST",
      path: "/api/admin/campaigns/:id/launch",
      purpose: "Launch a campaign. Requires confirm: true"
    },
    %{
      method: "POST",
      path: "/api/admin/ptp_campaigns/builds",
      purpose: "Create one PTP campaign end to end. Never launches"
    },
    %{
      method: "GET",
      path: "/api/admin/reports/ptp_coverage?month=YYYY-MM",
      purpose: "PTP delivery by user, campaign, band, and api_ref scope"
    }
  ]

  def show(conn, params) do
    with {:ok, topics} <- topics(params["topic"]) do
      guide = topics |> Enum.map(&Map.fetch!(@guides, &1)) |> Enum.join("\n\n---\n\n")

      if params["format"] == "json" do
        json(conn, %{version: @version, topics: topics, guide: guide, endpoints: @endpoints})
      else
        conn
        |> put_resp_content_type("text/markdown")
        |> send_resp(200, guide)
      end
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp topics(nil), do: {:ok, @topics}
  defp topics(""), do: {:ok, @topics}
  defp topics("all"), do: {:ok, @topics}
  defp topics(topic) when topic in @topics, do: {:ok, ["overview", topic] |> Enum.uniq()}
  defp topics(_), do: {:error, :unknown_topic}
end
