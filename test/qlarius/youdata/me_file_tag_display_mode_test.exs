defmodule Qlarius.YouData.MeFiles.MeFileTagDisplayModeTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.MeFiles.MeFile

  describe "update_tag_display_mode/2" do
    test "persists a switch back to the mode on a stale struct" do
      # LiveViews hold the MeFile loaded at mount and pass it on every switch.
      stale = Repo.insert!(%MeFile{tag_display_mode: "list"})

      assert {:ok, _} = MeFiles.update_tag_display_mode(stale, "tag")
      assert {:ok, _} = MeFiles.update_tag_display_mode(stale, "list")

      assert Repo.get!(MeFile, stale.id).tag_display_mode == "list"
    end
  end
end
