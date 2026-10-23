defmodule QlariusWeb.ZipSkipLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
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

    case Repo.query!("SELECT pg_get_serial_sequence('traits', 'id')") do
      %{rows: [[seq]]} when is_binary(seq) ->
        Repo.query!(
          "SELECT setval(to_regclass($1), (SELECT COALESCE(MAX(id), 1) FROM traits))",
          [seq]
        )

      _ ->
        :ok
    end

    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "zip-skip-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    token = "quixzip#{System.unique_integer([:positive])}"
    places = insert_category!("Places")

    work =
      places
      |> insert_trait!("Work #{token}")
      |> Ecto.Changeset.change(%{input_type: "single_select_zip", skip_exempt: false})
      |> Repo.update!()
      |> survey_trait!("Where do you work?")

    skip =
      insert_trait!(nil, "Prefer not to say", parent_trait_id: work.id)
      |> Ecto.Changeset.change(%{is_skipped_tag: true, display_order: 43_601})
      |> Repo.update!()

    home =
      places
      |> insert_trait!("Home #{token}")
      |> Ecto.Changeset.change(%{input_type: "single_select_zip", skip_exempt: true})
      |> Repo.update!()
      |> survey_trait!("Where do you live?")

    insert_trait!(nil, "Prefer not to say", parent_trait_id: home.id)
    |> Ecto.Changeset.change(%{is_skipped_tag: true, display_order: 2})
    |> Repo.update!()

    %{conn: log_in_user(conn, user), user: user, token: token, work: work, skip: skip, home: home}
  end

  test "work zip can be skipped and the zip field does not list that answer", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder?q=#{ctx.token}")
    render_async(view)

    assert has_element?(
             view,
             "#trait-card-#{ctx.work.id} button[phx-click='skip_parent_trait']"
           )

    refute has_element?(
             view,
             "#trait-card-#{ctx.home.id} button[phx-click='skip_parent_trait']"
           )

    view |> element("#trait-card-#{ctx.work.id}") |> render_click()
    html = render(view)
    assert html =~ "zip-code-input"
    refute html =~ "value=\"#{ctx.skip.id}\""

    view |> element("#trait-card-#{ctx.work.id} button[phx-click='skip_parent_trait']") |> render_click()

    me_file_id = Repo.preload(ctx.user, :me_file).me_file.id

    assert Repo.one!(
             from mt in MeFileTag,
               where: mt.me_file_id == ^me_file_id and mt.trait_id == ^ctx.skip.id,
               select: mt.tag_value
           ) == "Prefer not to say"
  end
end
