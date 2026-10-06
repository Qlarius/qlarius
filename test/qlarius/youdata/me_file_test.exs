defmodule Qlarius.YouData.MeFiles.MeFileTest do
  use ExUnit.Case, async: true

  alias Qlarius.YouData.MeFiles.MeFile

  describe "changeset/2 tag_display_mode" do
    test "accepts tag and list" do
      for mode <- ~w(tag list) do
        changeset = MeFile.changeset(%MeFile{user_id: 1}, %{tag_display_mode: mode})
        assert changeset.valid?
        assert Ecto.Changeset.get_field(changeset, :tag_display_mode) == mode
      end
    end

    test "defaults to list" do
      assert %MeFile{}.tag_display_mode == "list"
    end

    test "rejects invalid display mode" do
      for mode <- ~w(grid block) do
        changeset = MeFile.changeset(%MeFile{user_id: 1}, %{tag_display_mode: mode})
        refute changeset.valid?
        assert "is invalid" in errors_on(changeset).tag_display_mode
      end
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
