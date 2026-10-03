defmodule QlariusWeb.Api.Admin.MarketerControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Accounts.{AdminApiTokens, Marketer, MarketerUser, User}
  alias Qlarius.Repo

  @guide "/api/admin/agent_guide"

  setup do
    admin =
      %User{}
      |> User.registration_changeset(%{
        "alias" => "api-admin-#{System.unique_integer([:positive])}"
      })
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Repo.insert!()

    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{token: raw, admin: admin}
  end

  defp authed(token), do: build_conn() |> put_req_header("authorization", "Bearer #{token}")

  defp marketer!(attrs) do
    %Marketer{} |> Marketer.changeset(Map.new(attrs)) |> Repo.insert!()
  end

  test "refuses a missing token" do
    conn = get(build_conn(), ~p"/api/admin/marketers")
    assert %{"error" => "unauthorized", "guide" => @guide} = json_response(conn, 401)
  end

  test "the guide serves the campaigns topic with the api_ref rules", %{token: token} do
    body =
      token
      |> authed()
      |> get(~p"/api/admin/agent_guide?topic=campaigns&format=json")
      |> json_response(200)

    assert body["topics"] == ["overview", "campaigns"]
    assert body["guide"] =~ "API reference keys (required)"
    assert body["guide"] =~ "ptp-2610-joes_tacos-phx.marketer"
    assert Enum.any?(body["endpoints"], &(&1["path"] == "/api/admin/marketers"))
  end

  describe "create" do
    test "requires an api_ref", %{token: token} do
      body =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", %{business_name: "Joe's Tacos"})
        |> json_response(422)

      assert %{"error" => "api_ref_required", "guide" => @guide} = body
      assert body["message"] =~ "topic=campaigns"
    end

    test "rejects a malformed api_ref", %{token: token} do
      body =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", %{business_name: "Joe's Tacos", api_ref: "Has Spaces"})
        |> json_response(422)

      assert body["error"] == "invalid_api_ref"
    end

    test "dry run validates without writing", %{token: token} do
      before = Repo.aggregate(Marketer, :count)

      body =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", %{
          api_ref: "ptp-2610-joes_tacos-phx.marketer",
          business_name: "Joe's Tacos",
          dry_run: true
        })
        |> json_response(200)

      assert %{"result" => "would_create", "matched" => false} = body
      assert body["marketer"]["business_name"] == "Joe's Tacos"
      assert Repo.aggregate(Marketer, :count) == before
    end

    test "dry run reports validation errors", %{token: token} do
      body =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", %{
          api_ref: "ptp-2610-joes_tacos-phx.marketer",
          dry_run: true
        })
        |> json_response(422)

      assert %{"error" => "invalid", "errors" => %{"business_name" => [_]}} = body
    end

    test "creates once, then matches on the same api_ref", %{token: token} do
      params = %{
        api_ref: "ptp-2610-joes_tacos-phx.marketer",
        business_name: "Joe's Tacos",
        business_url: "https://joestacos.example"
      }

      before = Repo.aggregate(Marketer, :count)

      created = token |> authed() |> post(~p"/api/admin/marketers", params) |> json_response(201)
      assert %{"result" => "created", "matched" => false} = created
      assert created["marketer"]["api_ref"] == "ptp-2610-joes_tacos-phx.marketer"

      again = token |> authed() |> post(~p"/api/admin/marketers", params) |> json_response(200)
      assert %{"result" => "matched", "matched" => true, "differences" => diff} = again
      assert diff == %{}
      assert again["marketer"]["id"] == created["marketer"]["id"]
      assert Repo.aggregate(Marketer, :count) == before + 1
    end

    test "reports differences and only updates with on_existing update", %{token: token} do
      marketer!(api_ref: "ptp-2610-joes_tacos-phx.marketer", business_name: "Joe's Tacos")

      params = %{api_ref: "ptp-2610-joes_tacos-phx.marketer", business_name: "Joe's Tacos PHX"}

      skipped = token |> authed() |> post(~p"/api/admin/marketers", params) |> json_response(200)
      assert %{"result" => "matched", "differences" => %{"business_name" => diff}} = skipped
      assert diff == %{"current" => "Joe's Tacos", "requested" => "Joe's Tacos PHX"}
      assert Repo.get_by!(Marketer, api_ref: params.api_ref).business_name == "Joe's Tacos"

      preview =
        token
        |> authed()
        |> post(
          ~p"/api/admin/marketers",
          Map.merge(params, %{on_existing: "update", dry_run: true})
        )
        |> json_response(200)

      assert preview["result"] == "would_update"
      assert Repo.get_by!(Marketer, api_ref: params.api_ref).business_name == "Joe's Tacos"

      updated =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", Map.put(params, :on_existing, "update"))
        |> json_response(200)

      assert updated["result"] == "updated"
      assert Repo.get_by!(Marketer, api_ref: params.api_ref).business_name == "Joe's Tacos PHX"
    end

    test "rejects an unknown on_existing", %{token: token} do
      marketer!(api_ref: "ptp-2610-joes_tacos-phx.marketer", business_name: "Joe's Tacos")

      body =
        token
        |> authed()
        |> post(~p"/api/admin/marketers", %{
          api_ref: "ptp-2610-joes_tacos-phx.marketer",
          business_name: "Other",
          on_existing: "replace"
        })
        |> json_response(422)

      assert body["error"] == "invalid_on_existing"
    end
  end

  describe "index and show" do
    test "filters by name, domain and api_ref prefix with counts", %{token: token} do
      joes =
        marketer!(
          api_ref: "ptp-2610-joes_tacos-phx.marketer",
          business_name: "Joe's Tacos",
          business_url: "https://www.joestacos.example/menu"
        )

      marketer!(business_name: "Pet Barn", business_url: "https://petbarn.example")

      body = token |> authed() |> get(~p"/api/admin/marketers?q=taco") |> json_response(200)
      assert [%{"id" => id, "counts" => counts}] = body["marketers"]
      assert id == joes.id
      assert counts["campaigns"] == 0 and counts["members"] == 0

      body =
        token
        |> authed()
        |> get(~p"/api/admin/marketers?domain=https://joestacos.example")
        |> json_response(200)

      assert [%{"id" => ^id}] = body["marketers"]

      body =
        token
        |> authed()
        |> get(~p"/api/admin/marketers?api_ref_prefix=ptp-2610-joes_tacos")
        |> json_response(200)

      assert [%{"id" => ^id}] = body["marketers"]

      body = token |> authed() |> get(~p"/api/admin/marketers/#{id}") |> json_response(200)
      assert body["marketer"]["business_name"] == "Joe's Tacos"
    end

    test "show returns not_found with the guide", %{token: token} do
      body = token |> authed() |> get(~p"/api/admin/marketers/0") |> json_response(404)
      assert %{"error" => "not_found", "guide" => @guide} = body
    end
  end

  describe "update" do
    test "patches fields and refuses an api_ref change", %{token: token} do
      marketer = marketer!(api_ref: "ptp-2610-joes_tacos-phx.marketer", business_name: "Joe's")

      body =
        token
        |> authed()
        |> patch(~p"/api/admin/marketers/#{marketer.id}", %{business_name: "Joe's Tacos"})
        |> json_response(200)

      assert body["result"] == "updated"
      assert body["marketer"]["business_name"] == "Joe's Tacos"

      body =
        token
        |> authed()
        |> patch(~p"/api/admin/marketers/#{marketer.id}", %{
          api_ref: "ptp-2610-other-phx.marketer"
        })
        |> json_response(422)

      assert body["error"] == "api_ref_immutable"
    end
  end

  describe "delete" do
    test "dry run then deletes a marketer with no dependents", %{token: token} do
      marketer = marketer!(business_name: "Joe's Tacos")

      body =
        token
        |> authed()
        |> delete(~p"/api/admin/marketers/#{marketer.id}?dry_run=true")
        |> json_response(200)

      assert body["result"] == "would_delete"
      assert Repo.get(Marketer, marketer.id)

      body =
        token |> authed() |> delete(~p"/api/admin/marketers/#{marketer.id}") |> json_response(200)

      assert body["result"] == "deleted"
      refute Repo.get(Marketer, marketer.id)
    end

    test "refuses when the marketer has members", %{token: token, admin: admin} do
      marketer = marketer!(business_name: "Joe's Tacos")
      Repo.insert!(%MarketerUser{marketer_id: marketer.id, user_id: admin.id, role: :owner})

      body =
        token |> authed() |> delete(~p"/api/admin/marketers/#{marketer.id}") |> json_response(409)

      assert %{"error" => "has_dependents", "dependents" => %{"members" => 1}} = body
      assert Repo.get(Marketer, marketer.id)
    end
  end
end
