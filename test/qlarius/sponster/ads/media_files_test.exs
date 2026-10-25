defmodule Qlarius.Sponster.Ads.MediaFilesTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategory, MediaFiles, MediaPiece, MediaPieceType}

  test "keeps a clean version of the original file name" do
    assert MediaFiles.descriptive_name("Brand Slug_alt1.PNG") == "brand-slug_alt1.png"
    assert MediaFiles.descriptive_name("weird file (final).JPG") == "weird-file-final.jpg"
    assert MediaFiles.descriptive_name("") == "file"
  end

  test "does not overwrite a file that already uses that name" do
    n = System.unique_integer([:positive])
    original = "Brand Slug #{n}_alt1.PNG"
    first = "brand-slug-#{n}_alt1.png"
    second = "brand-slug-#{n}_alt1_2.png"
    paths = [banner_path(first), banner_path(second)]
    on_exit(fn -> Enum.each(paths, &File.rm/1) end)

    assert MediaFiles.store!(write_temp!("first"), original, :banner) == first
    assert File.read!(banner_path(first)) == "first"

    assert MediaFiles.store!(write_temp!("second"), original, :banner) == second
    assert File.read!(banner_path(first)) == "first"
    assert File.read!(banner_path(second)) == "second"
  end

  test "skips a name already stored on a media piece" do
    n = System.unique_integer([:positive])
    original = "Stored #{n}.png"
    taken = "stored-#{n}.png"
    suffix = "stored-#{n}_2.png"
    on_exit(fn -> File.rm(banner_path(suffix)) end)

    insert_piece!(taken)

    assert MediaFiles.store!(write_temp!("bytes"), original, :banner) == suffix
    refute File.exists?(banner_path(taken))
  end

  test "a video name blocks the same banner name" do
    n = System.unique_integer([:positive])
    taken = "clip-#{n}.mp4"
    on_exit(fn -> File.rm(banner_path("clip-#{n}_2.mp4")) end)

    insert_piece!(nil, video_file: taken)

    assert MediaFiles.store!(write_temp!("bytes"), "clip-#{n}.mp4", :banner) == "clip-#{n}_2.mp4"
  end

  test "lists media pieces that share a file name" do
    n = System.unique_integer([:positive])
    name = "shared-#{n}.png"
    first = insert_piece!(name)
    second = insert_piece!(name)

    group = Enum.find(MediaFiles.shared_filenames(), &(&1.filename == name))

    assert Enum.sort(Enum.map(group.pieces, & &1.id)) == Enum.sort([first.id, second.id])
    assert Enum.all?(group.pieces, &(&1.field == :banner_image))
  end

  test "s3 upload asks not to replace an existing object" do
    operation = ExAws.S3.put_object("bucket", "uploads/x.png", "body", if_none_match: "*")
    assert operation.headers["if-none-match"] == "*"

    source =
      __DIR__
      |> Path.join("../../../../lib/qlarius/sponster/ads/media_files.ex")
      |> Path.expand()
      |> File.read!()

    assert source =~ ~s(if_none_match: "*")
  end

  defp banner_path(filename) do
    Path.join([
      :code.priv_dir(:qlarius),
      "static",
      "uploads",
      "media_pieces",
      "banners",
      "three_tap_banners",
      filename
    ])
  end

  defp write_temp!(contents) do
    path = Path.join(System.tmp_dir!(), "qlarius-media-#{System.unique_integer([:positive])}")
    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp insert_piece!(banner, opts \\ []) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    ensure_three_tap_type!(now)
    marketer = Repo.insert!(Marketer.changeset(%Marketer{}, %{business_name: "M #{uniq()}"}))
    category = insert_category!()

    %MediaPiece{}
    |> MediaPiece.changeset(%{
      title: "Piece",
      body_copy: "Body",
      media_piece_type_id: 1,
      ad_category_id: category.id,
      marketer_id: marketer.id,
      active: true,
      banner_image: banner || "banner-#{uniq()}.png",
      video_file: opts[:video_file],
      display_url: "example.com",
      jump_url: "https://example.com/jump"
    })
    |> Repo.insert!()
  end

  defp ensure_three_tap_type!(now) do
    unless Repo.get(MediaPieceType, 1) do
      Repo.insert!(%MediaPieceType{
        id: 1,
        name: "three_tap",
        desc: "3-tap",
        ad_phase_count_to_complete: 2,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: now
      })
    end
  end

  defp insert_category! do
    n = uniq()
    row_id = "MF-" <> (n |> Integer.to_string() |> String.pad_leading(2, "0"))

    %AdCategory{}
    |> AdCategory.create_changeset(%{
      row_id: row_id,
      category_id: "TEST",
      category_name: "Test",
      category_label: "Test",
      ad_label: "Cat #{n}",
      sales_channel_default: "local",
      sort_order: n,
      cohort: "legacy",
      active: true
    })
    |> Repo.insert!()
  end

  defp uniq, do: System.unique_integer([:positive])
end
