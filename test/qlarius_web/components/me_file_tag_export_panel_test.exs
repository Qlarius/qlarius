defmodule QlariusWeb.MeFileTagExportPanelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "the locked panel masks the phone and does not show the export" do
    html =
      render_component(QlariusWeb.MeFileTagExportPanel,
        id: "me-file-tag-export-panel",
        current_scope: %{
          true_user: %{mobile_number_encrypted: "+15551234567"},
          user: %{me_file: %{id: 1}}
        }
      )

    assert html =~ "MeFile Tag Export"
    assert html =~ "Text me a code"
    assert html =~ "6-digit code"
    assert html =~ "usually best kept zero-party"
    assert html =~ "···4567"
    refute html =~ "acting as a proxy"
    refute html =~ "5551234567"
    refute html =~ "mefile-tag-export\""
    refute html =~ ~s(id="mefile-tag-export")
  end

  test "an account with no mobile number cannot send a code" do
    html =
      render_component(QlariusWeb.MeFileTagExportPanel,
        id: "me-file-tag-export-panel",
        current_scope: %{
          true_user: %{mobile_number_encrypted: nil},
          user: %{me_file: %{id: 1}}
        }
      )

    assert html =~ "Add a mobile number"
    refute html =~ "Text me a code"
  end

  test "the proxy note shows only while an admin is using a proxy" do
    admin_proxy =
      render_component(QlariusWeb.MeFileTagExportPanel,
        id: "me-file-tag-export-panel",
        current_scope: %{
          true_user: %{id: 1, role: "admin", mobile_number_encrypted: "+15551234567"},
          user: %{id: 2, me_file: %{id: 9}}
        }
      )

    own_mefile =
      render_component(QlariusWeb.MeFileTagExportPanel,
        id: "me-file-tag-export-panel",
        current_scope: %{
          true_user: %{id: 1, role: "admin", mobile_number_encrypted: "+15551234567"},
          user: %{id: 1, me_file: %{id: 9}}
        }
      )

    assert admin_proxy =~ "While you are acting as a proxy"
    refute own_mefile =~ "While you are acting as a proxy"
  end
end
