defmodule QlariusWeb.Api.Admin.MediaPieceTypeControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Accounts.{AdminApiTokens, User}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPieceType

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{token: raw}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  test "refuses a missing token" do
    conn = get(build_conn(), ~p"/api/admin/media_piece_types")
    assert json_response(conn, 401)["error"] == "unauthorized"
  end

  test "lists types with pricing, required fields, and writability", %{token: token} do
    unless Repo.get(MediaPieceType, 1) do
      Repo.insert!(%MediaPieceType{
        id: 1,
        name: "3-Tap",
        desc: "3-Tap",
        ad_phase_count_to_complete: 2,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
    end

    body =
      token |> authed() |> get(~p"/api/admin/media_piece_types") |> json_response(200)

    three_tap = Enum.find(body["media_piece_types"], &(&1["id"] == 1))
    assert three_tap["required_fields"] == ["banner_image", "display_url", "jump_url"]
    assert three_tap["writable"] == true
    assert three_tap["base_fee"] == "0.10"
    assert three_tap["markup_multiplier"] == "1.50" or three_tap["markup_multiplier"] == "1.5"

    video = Enum.find(body["media_piece_types"], &(&1["id"] == 2))

    if video do
      assert video["writable"] == false
      assert video["required_fields"] == ["video_file", "duration"]
    end
  end
end
