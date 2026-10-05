defmodule QlariusWeb.LayoutsShellWidthTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Layouts

  describe "shell_width/2" do
    test "grid screens get the wide column" do
      for path <- ~w(/home /me_file_builder /arqade /arqade/creator/1 /content/9 /tiqits) do
        assert Layouts.shell_width(path, nil) == "wide", path
      end
    end

    test "MeFile is wide in Tags and Blocks, column in List" do
      assert Layouts.shell_width("/me_file", "tag") == "wide"
      assert Layouts.shell_width("/me_file", "block") == "wide"
      assert Layouts.shell_width("/me_file", "list") == "column"
      assert Layouts.shell_width("/me_file", nil) == "column"
    end

    test "other screens and missing paths use the reading column" do
      for path <- ["/wallet", "/ads", "/settings", "/me_file/connectors", nil] do
        assert Layouts.shell_width(path, "tag") == "column", inspect(path)
      end
    end
  end
end
