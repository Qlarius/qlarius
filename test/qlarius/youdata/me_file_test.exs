defmodule Qlarius.YouData.MeFiles.MeFileTest do
  use ExUnit.Case, async: true

  alias Qlarius.YouData.MeFiles.MeFile

  describe "changeset/2 tag_display_mode" do
    test "accepts tag, block, and list" do
      for mode <- ~w(tag block list) do
        changeset = MeFile.changeset(%MeFile{user_id: 1}, %{tag_display_mode: mode})
        assert changeset.valid?
        assert Ecto.Changeset.get_change(changeset, :tag_display_mode) == mode
      end
    end

    test "rejects invalid display mode" do
      changeset = MeFile.changeset(%MeFile{user_id: 1}, %{tag_display_mode: "grid"})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).tag_display_mode
    end

  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
