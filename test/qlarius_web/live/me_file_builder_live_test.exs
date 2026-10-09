defmodule QlariusWeb.MeFileBuilderLiveTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qlarius.MeCPFixtures

  alias Qlarius.Accounts
  alias Qlarius.MeCP.Suggestions
  alias Qlarius.MeCP.Suggestions.TagSuggestion
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
        alias: "builder-lv-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01],
        sex_trait_id: 200_001,
        age_trait_id: 200_093
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  # Arts and Crafts (multi-select, in an active survey) with Painting on file
  # and a Qai suggestion that mentions Painting and Pottery.
  defp seed_suggestion(%{user: user}) do
    me_file = Repo.preload(user, :me_file).me_file
    hobbies = insert_category!("Hobbies")

    crafts =
      hobbies
      |> insert_trait!("Arts and Crafts")
      |> Ecto.Changeset.change(input_type: "multi_select")
      |> Repo.update!()
      |> survey_trait!("Select the arts and crafts activities below that interest you.")

    painting = insert_trait!(nil, "Painting", parent_trait_id: crafts.id, display_order: 1)
    pottery = insert_trait!(nil, "Pottery", parent_trait_id: crafts.id, display_order: 2)
    insert_tag!(me_file, painting, "Painting")

    grant = insert_grant!(me_file, insert_client!(%{name: "Qai"}), %{tier: 2, scope: %{}})

    {:ok, suggestion} =
      Suggestions.create_suggestion(grant, crafts.id, %{
        proposed_values: ["Painting", "Pottery"],
        reason: "User mentioned they are considering taking up pottery."
      })

    %{
      me_file: me_file,
      crafts: crafts,
      painting: painting,
      pottery: pottery,
      suggestion: suggestion
    }
  end

  describe "Qai suggestions" do
    setup :seed_suggestion

    test "the card names the trait and the new value; a tap opens its editor pre-ticked", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder")
      html = render_async(view)

      card = "#qai-suggestion-#{ctx.suggestion.id}"
      assert has_element?(view, card, "Arts and Crafts")
      assert has_element?(view, "#{card} .qai-suggestion__add", "Add Pottery")
      refute has_element?(view, "#{card} .qai-suggestion__add", "Painting")
      assert html =~ "Suggested by Qai"

      view |> element("#{card} button[phx-click=open_suggestion]") |> render_click()

      assert has_element?(view, ".tag-edit-modal.modal-open")
      assert has_element?(view, "#trait-#{ctx.pottery.id}[checked]")
      assert has_element?(view, "#trait-#{ctx.painting.id}[checked]")
      assert has_element?(view, ".tag-option--from-chat", "Pottery")
      assert has_element?(view, ".tag-edit-chat-note", "Ticked from your chat: Pottery")
    end

    test "saving the editor adds the value and resolves the suggestion", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder?suggestion=#{ctx.suggestion.id}")
      render_async(view)
      assert has_element?(view, "#trait-#{ctx.pottery.id}[checked]")

      render_hook(view, "save_tags", %{
        "me_file_id" => to_string(ctx.me_file.id),
        "trait_id" => to_string(ctx.crafts.id),
        "child_trait_ids" => [to_string(ctx.painting.id), to_string(ctx.pottery.id)]
      })

      tagged =
        ctx.me_file.id
        |> Qlarius.YouData.MeFiles.existing_tags_per_parent_trait(ctx.crafts.id)
        |> Enum.map(& &1.trait_id)
        |> Enum.sort()

      assert tagged == Enum.sort([ctx.painting.id, ctx.pottery.id])
      assert Repo.get!(TagSuggestion, ctx.suggestion.id).status == "accepted"
      refute has_element?(view, "#qai-suggestion-#{ctx.suggestion.id}")
    end

    test "a link to someone else's or a resolved suggestion opens nothing", ctx do
      other = Repo.insert!(%Qlarius.YouData.MeFiles.MeFile{})
      grant = insert_grant!(other, insert_client!(), %{tier: 2, scope: %{}})
      {:ok, theirs} = Suggestions.create_suggestion(grant, ctx.crafts.id, %{})

      {:ok, view, html} = live(ctx.conn, ~p"/me_file_builder?suggestion=#{theirs.id}")
      assert html =~ "That suggestion has already been answered or dismissed."
      refute has_element?(view, ".tag-edit-modal.modal-open")
    end

    test "Dismiss removes the card", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder")
      render_async(view)

      view
      |> element("#qai-suggestion-#{ctx.suggestion.id} button[phx-click=dismiss_suggestion]")
      |> render_click()

      refute has_element?(view, "#qai-suggestion-#{ctx.suggestion.id}")
      assert Repo.get!(TagSuggestion, ctx.suggestion.id).status == "dismissed"
    end
  end

  describe "search" do
    setup :seed_suggestion

    test "?q= prefills the search; results name the trait and the tags on file", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder?q=pottery")

      assert has_element?(view, "#builder-trait-search-input[value=pottery]")
      render_async(view)

      assert has_element?(
               view,
               "#trait-card-#{ctx.crafts.id} .mefile-row__label",
               "Arts and Crafts"
             )

      assert has_element?(view, "#trait-card-#{ctx.crafts.id} .mefile-row__value", "Painting")
      assert has_element?(view, "#trait-card-#{ctx.crafts.id}", "Matches Pottery")

      view |> element("#trait-card-#{ctx.crafts.id}") |> render_click()

      assert has_element?(view, ".tag-edit-modal.modal-open")
      assert has_element?(view, "#trait-#{ctx.painting.id}[checked]")
      refute has_element?(view, "#trait-#{ctx.pottery.id}[checked]")
    end

    test "search terms find a trait; clearing the search shows the index again", ctx do
      ctx.pottery |> Ecto.Changeset.change(search_terms: ["ceramics"]) |> Repo.update!()
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder")
      render_async(view)

      view |> element("button[aria-label='Search topics and tags']") |> render_click()
      html = view |> form("#builder-trait-search", %{q: "ceramics"}) |> render_change()
      assert html =~ "builder-trait-results-skeleton" or html =~ "Arts and Crafts"

      render_async(view)

      assert has_element?(
               view,
               "#trait-card-#{ctx.crafts.id} .mefile-row__label",
               "Arts and Crafts"
             )

      assert has_element?(view, "#trait-card-#{ctx.crafts.id}", "Matches Pottery")
      refute has_element?(view, "#builder-trait-results-skeleton")

      html = view |> form("#builder-trait-search", %{q: "zzzunknown"}) |> render_change()
      assert html =~ "builder-results--pending"
      refute has_element?(view, "#builder-trait-results-skeleton")

      render_async(view)
      assert has_element?(view, "#builder-trait-results", ~s(No topics match "zzzunknown"))

      view |> element("button[phx-click=clear_trait_search]") |> render_click()
      refute has_element?(view, "#builder-trait-results")
      assert has_element?(view, "#qai-suggestion-#{ctx.suggestion.id}")

      view |> form("#builder-trait-search", %{q: "ca"}) |> render_change()
      refute has_element?(view, "#builder-trait-results")
      refute has_element?(view, "#builder-trait-results-skeleton")
      assert has_element?(view, "#qai-suggestion-#{ctx.suggestion.id}")
    end

    test "the Related link searches for the value from chat", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder")
      render_async(view)

      view |> element("#qai-suggestion-#{ctx.suggestion.id} a", "Related") |> render_click()
      assert_patch(view, ~p"/me_file_builder?q=Pottery")
      render_async(view)
      assert has_element?(view, "#builder-trait-results", "Arts and Crafts")
    end

    test "saving from a result shows the new tag values on that row", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/me_file_builder?q=pottery")
      render_async(view)

      render_hook(view, "save_tags", %{
        "me_file_id" => to_string(ctx.me_file.id),
        "trait_id" => to_string(ctx.crafts.id),
        "child_trait_ids" => [to_string(ctx.painting.id), to_string(ctx.pottery.id)]
      })

      assert has_element?(
               view,
               "#trait-card-#{ctx.crafts.id} .mefile-row__value",
               "Painting · Pottery"
             )

      view |> element("button[aria-label='Show as Tags']") |> render_click()

      assert has_element?(
               view,
               "#trait-card-#{ctx.crafts.id} .trait-tag__name",
               "Arts and Crafts"
             )

      assert has_element?(
               view,
               "#trait-card-#{ctx.crafts.id} .trait-tag__values",
               "Painting · Pottery"
             )

      assert has_element?(view, "#trait-card-#{ctx.crafts.id}", "Matches Pottery")
    end
  end

  test "the first paint is the index skeleton; the index replaces it once loaded", %{
    conn: conn
  } do
    dead = conn |> get(~p"/me_file_builder") |> html_response(200)
    assert dead =~ ~s(id="builder-index-skeleton")
    assert dead =~ ~s(aria-busy="true")
    assert dead =~ "Tap a topic to add or update its tags."

    {:ok, view, _html} = live(conn, ~p"/me_file_builder")
    html = render_async(view)

    refute html =~ "builder-index-skeleton"
    assert html =~ ~s(class="builder-index pt-2")
  end
end
