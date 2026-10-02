defmodule QlariusWeb.Api.Admin.AgentGuideController do
  @moduledoc """
  Serves the written how-to an AI agent reads before calling the admin API.
  """

  use QlariusWeb, :controller

  alias QlariusWeb.Api.Admin.Responder

  @version "2026-10-02.1"
  @guides_dir Path.expand("../../../../../priv/agent_guides", __DIR__)
  @topics ~w(overview content_groups traits ad_categories)

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
