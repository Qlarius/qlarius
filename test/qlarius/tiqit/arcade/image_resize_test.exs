defmodule Qlarius.Tiqit.Arcade.ImageResizeTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.{ImageResize, ImportImage}

  test "download cap is above the 5 MB store cap, and a larger file is shrunk" do
    assert ImportImage.download_max_bytes() > ImageResize.store_max_bytes()

    path =
      Path.join(System.tmp_dir!(), "qlarius-resize-#{System.unique_integer([:positive])}.jpg")

    {_, 0} =
      System.cmd(
        "ffmpeg",
        [
          "-y",
          "-f",
          "lavfi",
          "-i",
          "testsrc=size=640x480:rate=1",
          "-frames:v",
          "1",
          "-q:v",
          "2",
          path
        ],
        stderr_to_stdout: true
      )

    on_exit(fn -> File.rm(path) end)

    original = File.stat!(path).size
    assert original > 6_000
    assert :ok = ImageResize.fit(path, max_bytes: 6_000)
    assert File.stat!(path).size <= 6_000
    assert File.stat!(path).size < original
  end
end
