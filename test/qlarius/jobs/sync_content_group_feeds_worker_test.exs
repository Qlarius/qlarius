defmodule Qlarius.Jobs.SyncContentGroupFeedsWorkerTest do
  use Qlarius.DataCase, async: false

  import Ecto.Query
  import Qlarius.ContentImportHelpers

  alias Qlarius.Jobs.SyncContentGroupFeedsWorker
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentPiece, RssImporter}

  setup do
    stub_feed()
    :ok
  end

  test "adds new episodes to groups with daily sync on" do
    catalog = podcast_catalog_fixture()

    {:ok, %{content_group: %{id: synced_id}}} = import_trailer(catalog, true)
    {:ok, %{content_group: %{id: manual_id}}} = import_trailer(catalog, false)

    assert :ok = perform_job(SyncContentGroupFeedsWorker, %{})

    assert piece_count(synced_id) == 3
    assert piece_count(manual_id) == 1
  end

  defp import_trailer(catalog, auto_sync) do
    RssImporter.import_feed(%{
      "feed_url" => feed_url(),
      "catalog_id" => catalog.id,
      "season" => 3,
      "guids" => ["tm-s3-trailer"],
      "auto_sync" => auto_sync
    })
  end

  defp piece_count(group_id) do
    Repo.aggregate(from(p in ContentPiece, where: p.content_group_id == ^group_id), :count)
  end

  defp perform_job(worker, args), do: worker.perform(%Oban.Job{args: args})
end
