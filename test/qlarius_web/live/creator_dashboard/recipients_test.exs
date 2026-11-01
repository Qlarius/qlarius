defmodule QlariusWeb.CreatorDashboard.RecipientsTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipients
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    Repo.insert!(%Trait{
      id: 1,
      trait_name: "Sex",
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })

    Repo.insert!(%Trait{
      id: 93,
      trait_name: "Age",
      input_type: "text",
      display_order: 1,
      modified_by: 0,
      added_by: 0
    })

    male =
      Repo.insert!(%Trait{
        id: 910_001,
        parent_trait_id: 1,
        trait_name: "Male",
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })

    age =
      Repo.insert!(%Trait{
        id: 910_093,
        parent_trait_id: 93,
        trait_name: "25-34",
        input_type: "text",
        display_order: 1,
        modified_by: 0,
        added_by: 0
      })

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "pubs-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: male.id,
        age_trait_id: age.id
      })

    {:ok, creator} =
      %Creator{}
      |> Creator.changeset(%{"name" => "Cities West Media"})
      |> Repo.insert()

    {:ok, _phoenix} =
      Recipients.attach_to_creator(Accounts.Scope.for_user(user), creator, %{
        "name" => "PHOENIX Magazine",
        "site_url" => "https://phoenixmag.com"
      })

    %{conn: log_in_user(conn, user), creator: creator, user: user}
  end

  test "lists publications and adds another", %{conn: conn, creator: creator} do
    {:ok, view, html} = live(conn, ~p"/creators/#{creator.id}")

    assert html =~ "Recipients"
    assert html =~ "PHOENIX Magazine"
    assert html =~ "Primary"

    view
    |> form("#add-recipient",
      recipient: %{name: "Phoenix Home & Garden", site_url: "https://phgmag.com"}
    )
    |> render_submit()

    assert render(view) =~ "Phoenix Home &amp; Garden"
    assert render(view) =~ "phgmag.com"
  end

  test "catalog form lists the creator's recipients", %{conn: conn, creator: creator, user: user} do
    {:ok, _garden} =
      Recipients.attach_to_creator(Accounts.Scope.for_user(user), creator, %{
        "name" => "Phoenix Home & Garden",
        "site_url" => "https://phgmag.com"
      })

    {:ok, _view, html} = live(conn, ~p"/creators/#{creator.id}/catalogs/new")

    assert html =~ "Recipient"
    assert html =~ "PHOENIX Magazine (primary)"
    assert html =~ "Phoenix Home &amp; Garden"
  end
end
