defmodule QlariusWeb.TagQualityLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  setup %{conn: conn} do
    trait = fn attrs ->
      Repo.insert!(
        struct(
          Trait,
          Map.merge(%{input_type: "text", display_order: 1, modified_by: 0, added_by: 0}, attrs)
        )
      )
    end

    trait.(%{id: 1, trait_name: "Sex"})
    trait.(%{id: 93, trait_name: "Age"})
    trait.(%{id: 200_001, parent_trait_id: 1, trait_name: "Male"})
    trait.(%{id: 200_093, parent_trait_id: 93, trait_name: "25-34"})

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "quality-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    me_file = Repo.preload(user, :me_file).me_file
    me_file |> Ecto.Changeset.change(tag_display_mode: "tag") |> Repo.update!()

    hobbies = insert_category!("Money")

    income =
      hobbies
      |> insert_trait!("Zeltrane")
      |> Ecto.Changeset.change(%{input_type: "single_select", stale_days: 30, expired_days: 90})
      |> Repo.update!()
      |> survey_trait!("What is your Zeltrane?")

    high = insert_trait!(hobbies, "High", parent_trait_id: income.id)
    tag = insert_tag!(me_file, high, "High")

    added =
      Date.utc_today()
      |> Date.add(-120)
      |> NaiveDateTime.new!(~T[08:00:00])

    tag |> Ecto.Changeset.change(added_date: added) |> Repo.update!()

    brindle =
      hobbies
      |> insert_trait!("Brindle")
      |> Ecto.Changeset.change(%{
        input_type: "single_select",
        ripen_days: 1,
        nudge_text: "This helps you see more relevant offers"
      })
      |> Repo.update!()
      |> survey_trait!("What is your Brindle?")

    brindle_skip =
      hobbies
      |> insert_trait!("Prefer not to say", parent_trait_id: brindle.id)
      |> Ecto.Changeset.change(%{is_skipped_tag: true})
      |> Repo.update!()

    skip_tag = insert_tag!(me_file, brindle_skip, "Prefer not to say")

    skip_added =
      Date.utc_today()
      |> Date.add(-10)
      |> NaiveDateTime.new!(~T[08:00:00])

    skip_tag |> Ecto.Changeset.change(added_date: skip_added) |> Repo.update!()

    %{
      conn: log_in_user(conn, user),
      user: user,
      income: income,
      high: high,
      brindle: brindle
    }
  end

  test "a stale tag shows a red light, the edit sheet explains it, and saving freshens it",
       ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/me_file")
    html = render_async(view)

    assert html =~ "trait-signal--red"
    assert html =~ "Out of date. Saving confirms these values."

    view |> element("#trait-card-#{ctx.income.id}") |> render_click()
    assert render(view) =~ "Out of date. Saving confirms these values."

    view
    |> form("form[phx-submit='save_tags']", %{
      "me_file_id" => Repo.preload(ctx.user, :me_file).me_file.id,
      "trait_id" => ctx.income.id,
      "child_trait_ids" => [ctx.high.id]
    })
    |> render_submit()

    html = render(view)
    refute html =~ "trait-signal--red"
    refute html =~ "Out of date"
    assert html =~ "trait-signal--green"
  end

  test "builder results show the same red light", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder?q=zeltrane")
    html = render_async(view)

    assert html =~ "trait-signal--red"
    assert html =~ "Needs attention: Out of date. Saving confirms these values."
  end

  test "a skip fills the hole with the tag border, and the builder shows its nudge once it has ripened",
       ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/me_file")
    html = render_async(view)

    assert html =~ "trait-signal--neutral"
    refute html =~ "trait-signal--skipped"
    refute html =~ "This helps you see more relevant offers"

    {:ok, builder, _html} = live(ctx.conn, ~p"/me_file_builder?q=brindle")
    builder_html = render_async(builder)
    assert builder_html =~ "trait-signal--neutral"
    assert builder_html =~ "trait-nudge"
    assert builder_html =~ "This helps you see more relevant offers"
  end
end
