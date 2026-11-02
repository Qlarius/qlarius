defmodule Qlarius.Sponster.MarketingTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Sponster.Marketing

  test "a failed banner upload returns the storage error" do
    path = Path.join(System.tmp_dir!(), "missing-banner-#{System.unique_integer([:positive])}")

    upload = %Plug.Upload{path: path, filename: "banner.png", content_type: "image/png"}

    assert {:error, {:upload_failed, :banner_image, message}} =
             Marketing.create_media_piece(%{"banner_image" => upload})

    assert message =~ "could not read"
    refute message =~ "is invalid"
  end
end
