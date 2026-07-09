defmodule Qlarius.MeCPTest do
  use Qlarius.DataCase, async: true

  import Qlarius.MeCPFixtures

  alias Qlarius.MeCP
  alias Qlarius.MeCP.Clients.Client
  alias Qlarius.MeCP.Export
  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.YouData.MeFiles.MeFile

  describe "create_connector/2" do
    setup do
      %{me_file: Repo.insert!(%MeFile{})}
    end

    test "creates client, grant, and token in one step", %{me_file: me_file} do
      demo = insert_category!("Demographics")

      assert {:ok, %{client: client, grant: grant, token: token}} =
               MeCP.create_connector(me_file, %{
                 name: "My Claude connector",
                 tier: 2,
                 category_ids: [demo.id],
                 budget_max: 50
               })

      assert client.client_type == "byo_assistant"
      assert client.status == "active"
      assert grant.tier == 2
      assert grant.scope == %{"category_ids" => [demo.id]}
      assert grant.budget == %{"period" => "day", "max" => 50}
      assert String.starts_with?(token, "mecp_")

      # The token authenticates back to this grant.
      assert Grants.get_grant_by_token(token).id == grant.id
    end

    test "no categories means full scope; no budget means unlimited", %{me_file: me_file} do
      assert {:ok, %{grant: grant}} =
               MeCP.create_connector(me_file, %{name: "Open connector", category_ids: []})

      assert grant.scope == %{}
      assert grant.budget == %{}
      assert grant.tier == 3
    end

    test "invalid attrs roll the whole transaction back", %{me_file: me_file} do
      assert {:error, %Ecto.Changeset{}} = MeCP.create_connector(me_file, %{name: nil})
      assert Repo.aggregate(Client, :count) == 0
      assert Repo.aggregate(Grant, :count) == 0
    end
  end

  describe "Export.build/2" do
    test "exports the taxonomy structure with dates" do
      ctx = seed!(%{scope: %{}})
      me_file = MeCP.load_me_file(ctx.me_file.id)

      export = Export.build(me_file, exported_at: ~U[2026-07-09 12:00:00Z])

      assert export["schema"] == "qlarius.mefile"
      assert export["schema_version"] == "1"
      assert export["exported_at"] == "2026-07-09T12:00:00Z"
      assert export["me_file"]["created_at"]

      categories = export["me_file"]["categories"]
      assert length(categories) == 2

      housing_value =
        categories
        |> Enum.flat_map(& &1["traits"])
        |> Enum.find(&(&1["id"] == ctx.housing.id))
        |> Map.fetch!("values")
        |> hd()

      assert housing_value["value"] == "Renter"
      assert housing_value["added_date"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "export is deterministic and JSON-encodable" do
      ctx = seed!(%{scope: %{}})
      me_file = MeCP.load_me_file(ctx.me_file.id)
      at = ~U[2026-07-09 12:00:00Z]

      a = Export.build(me_file, exported_at: at)
      b = Export.build(me_file, exported_at: at)

      assert Jason.encode!(a) == Jason.encode!(b)
    end
  end
end
