defmodule Qlarius.ContentImportHelpers do
  @moduledoc """
  Catalog setup and a stubbed network for content import tests. Feed paths
  ending in `.xml` return the Texas Monthly fixture; everything else is 404,
  so artwork downloads fail softly and nothing is written to disk.
  """

  import Qlarius.TargetingFixtures

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup}

  @feed_path Path.expand("fixtures/rss/texas_monthly_true_crime.xml", __DIR__)

  def feed_url, do: "https://feeds.example.com/true-crime.xml"

  def feed_xml, do: File.read!(@feed_path)

  @doc """
  Pass `images: true` to also serve `.jpg` artwork. Pair it with
  `use_tmp_uploads/0` so stored files land in a temp dir.
  """
  def stub_feed(xml \\ nil, opts \\ []) do
    xml = xml || feed_xml()
    images? = Keyword.get(opts, :images, false)

    Req.Test.stub(Qlarius.Tiqit.Arcade.ImportHttp, fn conn ->
      cond do
        String.ends_with?(conn.request_path, ".xml") ->
          conn
          |> Plug.Conn.put_resp_content_type("application/rss+xml")
          |> Plug.Conn.send_resp(200, xml)

        images? and String.ends_with?(conn.request_path, ".jpg") ->
          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "fake jpeg bytes")

        true ->
          Plug.Conn.send_resp(conn, 404, "")
      end
    end)
  end

  def use_tmp_uploads do
    previous = Application.get_env(:waffle, :storage_dir_prefix)
    dir = Path.join(System.tmp_dir!(), "qlarius-uploads-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Application.put_env(:waffle, :storage_dir_prefix, dir)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:waffle, :storage_dir_prefix, previous)
      File.rm_rf(dir)
    end)

    dir
  end

  def podcast_catalog_fixture do
    creator = creator_fixture()

    %Catalog{creator_id: creator.id}
    |> Catalog.changeset(%{
      name: "Podcasts #{System.unique_integer([:positive])}",
      url: "https://example.com/#{System.unique_integer([:positive])}",
      type: :catalog,
      group_type: :show,
      piece_type: :episode
    })
    |> Repo.insert!()
    |> Repo.preload(:creator)
  end

  def content_group_fixture(catalog, attrs \\ %{}) do
    %ContentGroup{catalog_id: catalog.id}
    |> ContentGroup.changeset(Map.merge(%{title: "Show"}, attrs))
    |> Repo.insert!()
  end
end
