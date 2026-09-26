defmodule QlariusWeb.Api.Admin.CatalogControllerTest do
  use QlariusWeb.ConnCase, async: false

  alias Qlarius.Accounts.AdminApiTokens
  alias Qlarius.Accounts.User
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait

  setup do
    admin = user("admin")
    {:ok, _token, raw} = AdminApiTokens.issue(admin, "test")
    %{admin: admin, token: raw}
  end

  test "rejects unauthenticated writes" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/admin/traits/design_packs", Jason.encode!(%{mode: "create"}))

    assert %{"error" => "unauthorized"} = json_response(conn, 401)
  end

  test "rejects a non-admin token", %{admin: admin, token: raw} do
    admin |> Ecto.Changeset.change(role: "user") |> Repo.update!()

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/admin/traits/design_packs", Jason.encode!(%{mode: "create"}))

    assert %{"error" => "forbidden"} = json_response(conn, 403)
  end

  test "creates a parent with children, question, and expanded answers", %{
    token: token,
    admin: admin
  } do
    category =
      authed(token)
      |> post(
        ~p"/api/admin/trait_categories",
        Jason.encode!(%{"name" => "Fun #{unique()}", "display_order" => 1})
      )
      |> json_response(201)

    body =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{
          "trait_name" => "Event Types #{unique()}",
          "input_type" => "multi_select",
          "display_order" => 4,
          "trait_category_id" => category["id"]
        },
        "survey_question" => %{"text" => "What kinds of live events do you go to?"},
        "children" => [
          %{
            "trait_name" => "Live music",
            "display_order" => 10,
            "survey_answer_text" => "Concerts and festivals."
          },
          %{"trait_name" => "Prefer not to say", "display_order" => 20, "is_skipped_tag" => true}
        ]
      })

    assert body["input_type"] == "multi_select"
    assert body["survey_question"]["text"] == "What kinds of live events do you go to?"
    assert body["deactivated_tag_count"] == 0

    [music, prefer] = Enum.filter(body["children"], & &1["is_active"])
    assert music["trait_name"] == "Live music"
    assert music["display_order"] == 1
    assert music["is_skipped_tag"] == false
    assert music["survey_answer"]["text"] == "Concerts and festivals."
    assert prefer["trait_name"] == "Prefer not to say"
    assert prefer["display_order"] == 2
    assert prefer["is_skipped_tag"] == true

    parent = Repo.get!(Trait, body["id"])
    assert parent.added_by == admin.id
    assert parent.modified_by == admin.id

    catalog = api(token, :get, ~p"/api/admin/traits_catalog", nil)
    encoded = Jason.encode!(catalog)
    assert encoded =~ parent.trait_name
    assert encoded =~ "multi_select"
    assert encoded =~ "What kinds of live events do you go to?"
  end

  test "catalog lists only active surveys that present a parent", %{token: token} do
    category =
      authed(token)
      |> post(
        ~p"/api/admin/trait_categories",
        Jason.encode!(%{"name" => "Presented #{unique()}", "display_order" => 1})
      )
      |> json_response(201)

    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{
          "trait_name" => "Presented #{unique()}",
          "input_type" => "single_select",
          "trait_category_id" => category["id"]
        },
        "survey_question" => %{"text" => "Which do you do?"},
        "children" => [%{"trait_name" => "One"}]
      })

    question_id = created["survey_question"]["id"]

    active =
      authed(token)
      |> post(
        ~p"/api/admin/surveys",
        Jason.encode!(%{"name" => "Live #{unique()}", "active" => true})
      )
      |> json_response(201)

    inactive =
      authed(token)
      |> post(
        ~p"/api/admin/surveys",
        Jason.encode!(%{"name" => "Off #{unique()}", "active" => false})
      )
      |> json_response(201)

    for survey_id <- [active["id"], inactive["id"]] do
      api(token, :post, ~p"/api/admin/surveys/#{survey_id}/questions", %{
        "survey_question_id" => question_id,
        "display_order" => 1
      })
    end

    catalog = api(token, :get, ~p"/api/admin/traits_catalog", nil)

    parent =
      catalog["trait_categories"]
      |> Enum.flat_map(& &1["parent_traits"])
      |> Enum.find(&(&1["id"] == created["id"]))

    assert parent["active_survey_ids"] == [active["id"]]
  end

  test "saves lookup meta on children and finds them by code", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{
          "trait_name" => "Occupation #{unique()}",
          "input_type" => "single_select",
          "has_search_filter" => true
        },
        "survey_question" => %{"text" => "What is your occupation?"},
        "children" => [
          %{
            "trait_name" => "Software Developers",
            "survey_answer_text" => "Software Developers",
            "meta_1" => "15-1252",
            "meta_2" => "15-0000",
            "meta_3" => "programmer, software engineer"
          },
          %{"trait_name" => "Prefer not to say", "is_skipped_tag" => true}
        ]
      })

    software = Enum.find(created["children"], &(&1["trait_name"] == "Software Developers"))
    prefer = Enum.find(created["children"], &(&1["trait_name"] == "Prefer not to say"))
    assert created["has_search_filter"] == true
    assert software["meta_1"] == "15-1252"
    assert software["meta_2"] == "15-0000"
    assert software["meta_3"] == "programmer, software engineer"

    stored = Repo.get!(Trait, software["id"])
    assert stored.meta_1 == "15-1252"

    hits = api(token, :get, ~p"/api/admin/traits/#{created["id"]}/lookup?q=15-1252", nil)
    assert [%{"trait_name" => "Software Developers", "meta_1" => "15-1252"}] = hits["children"]

    title_hits =
      api(token, :get, ~p"/api/admin/traits/#{created["id"]}/lookup?q=engineer", nil)

    assert Enum.any?(title_hits["children"], &(&1["trait_name"] == "Software Developers"))

    reformed =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "reform",
        "parent" => %{"id" => created["id"]},
        "survey_question" => %{"text" => "What is your occupation?"},
        "children" => [
          %{"id" => software["id"], "trait_name" => "Software Developers"},
          %{"id" => prefer["id"], "trait_name" => "Prefer not to say"}
        ]
      })

    kept = Enum.find(reformed["children"], &(&1["id"] == software["id"]))
    assert kept["meta_1"] == "15-1252"
    assert kept["meta_3"] == "programmer, software engineer"
    assert reformed["has_search_filter"] == true

    cleared =
      api(token, :patch, ~p"/api/admin/traits/#{created["id"]}", %{
        "has_search_filter" => false
      })

    assert cleared["has_search_filter"] == false
  end

  test "tagging search text includes the title, answer, and every meta field" do
    text =
      QlariusWeb.Components.Targeting.tag_option_search_text(%{
        trait_name: "Software Developers",
        survey_answer: %{text: "Writes software"},
        meta_1: "15-1252",
        meta_2: "15-0000",
        meta_3: "programmer, software engineer"
      })

    assert text =~ "Software Developers"
    assert text =~ "Writes software"
    assert text =~ "15-1252"
    assert text =~ "15-0000"
    assert text =~ "programmer, software engineer"

    assert QlariusWeb.Components.Targeting.tag_option_answer(%{
             trait_name: "Software Developers",
             survey_answer: %{text: "Writes software"}
           }) == "Writes software"

    assert QlariusWeb.Components.Targeting.tag_option_answer(%{
             trait_name: "Software Developers",
             survey_answer: %{text: "Software Developers"}
           }) == ""
  end

  test "reform deactivates omitted children and keeps their tags", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{"trait_name" => "Going #{unique()}", "input_type" => "multi_select"},
        "survey_question" => %{"text" => "How often?"},
        "children" => [
          %{"trait_name" => "Concerts"},
          %{"trait_name" => "Weekly"}
        ]
      })

    concerts = Enum.find(created["children"], &(&1["trait_name"] == "Concerts"))
    weekly = Enum.find(created["children"], &(&1["trait_name"] == "Weekly"))
    me_file = Repo.insert!(%MeFile{})

    %MeFileTag{}
    |> MeFileTag.changeset(%{
      me_file_id: me_file.id,
      trait_id: concerts["id"],
      tag_value: "Concerts",
      added_by: 0,
      modified_by: 0
    })
    |> Repo.insert!()

    reformed =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "reform",
        "deactivate_missing_children" => true,
        "parent" => %{"id" => created["id"], "trait_name" => "Going-Out Frequency"},
        "survey_question" => %{"text" => "How often do you go out?"},
        "children" => [
          %{
            "id" => weekly["id"],
            "trait_name" => "Weekly or more",
            "survey_answer_text" => "Most weeks."
          }
        ]
      })

    assert reformed["trait_name"] == "Going-Out Frequency"
    assert concerts["id"] in reformed["deactivated_child_ids"]
    assert reformed["deactivated_tag_count"] == 1

    old = Enum.find(reformed["children"], &(&1["id"] == concerts["id"]))
    assert old["is_active"] == false
    assert old["me_file_tag_count"] == 1
    assert Repo.get_by!(MeFileTag, trait_id: concerts["id"])

    {:ok, loaded} = Traits.get_trait_with_full_survey_data!(created["id"])
    ids = Enum.map(loaded.child_traits, & &1.id)
    refute concerts["id"] in ids
    assert weekly["id"] in ids
  end

  test "updates survey answer text", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{"trait_name" => "Answers #{unique()}", "input_type" => "single_select"},
        "survey_question" => %{"text" => "Pick one"},
        "children" => [%{"trait_name" => "Rarely", "survey_answer_text" => "Rarely"}]
      })

    child = Enum.find(created["children"], &(&1["is_active"] && &1["trait_name"] == "Rarely"))
    answer_id = child["survey_answer"]["id"]

    updated =
      api(token, :patch, ~p"/api/admin/survey_answers/#{answer_id}", %{
        "text" => "Only special occasions, or almost never."
      })

    assert updated["text"] == "Only special occasions, or almost never."
  end

  test "rejects a child under a child", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{"trait_name" => "Depth #{unique()}", "input_type" => "multi_select"},
        "survey_question" => %{"text" => "Question"},
        "children" => [%{"trait_name" => "Only"}]
      })

    child = Enum.find(created["children"], &(&1["is_active"] && &1["trait_name"] == "Only"))

    conn =
      post(
        authed(token),
        ~p"/api/admin/traits/#{child["id"]}/children",
        Jason.encode!(%{"children" => [%{"trait_name" => "Nope"}]})
      )

    assert %{"error" => "child_under_child"} = json_response(conn, 422)
  end

  test "rejects age and zip child replacement without force", %{token: token} do
    age = ensure_age_parent()

    age_conn =
      post(
        authed(token),
        ~p"/api/admin/traits/design_packs",
        Jason.encode!(%{
          "mode" => "reform",
          "parent" => %{"id" => age.id, "trait_name" => "Age"},
          "survey_question" => %{"text" => "Age?"},
          "children" => [%{"trait_name" => "Nope"}]
        })
      )

    assert %{"error" => "protected_parent"} = json_response(age_conn, 422)

    zip_conn =
      post(
        authed(token),
        ~p"/api/admin/traits/design_packs",
        Jason.encode!(%{
          "mode" => "create",
          "parent" => %{"trait_name" => "Zip #{unique()}", "input_type" => "single_select_zip"},
          "survey_question" => %{"text" => "Zip?"},
          "children" => [%{"trait_name" => "00000"}]
        })
      )

    assert %{"error" => "protected_parent"} = json_response(zip_conn, 422)
  end

  test "a pasted Prefer not to say stays a normal answer", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{"trait_name" => "Opt out #{unique()}", "input_type" => "multi_select"},
        "survey_question" => %{"text" => "Any?"},
        "children" => [
          %{"trait_name" => "Yes"},
          %{"trait_name" => "Prefer not to say"}
        ]
      })

    active = Enum.filter(created["children"], & &1["is_active"])
    named = Enum.filter(active, &(&1["trait_name"] == "Prefer not to say"))

    assert length(named) == 2
    assert Enum.count(named, & &1["is_skipped_tag"]) == 1
    refute Enum.find(active, &(&1["trait_name"] == "Yes"))["is_skipped_tag"]
  end

  test "a flagged child is the opt-out and no extra label is inserted", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{"trait_name" => "Flagged #{unique()}", "input_type" => "single_select"},
        "survey_question" => %{"text" => "Any?"},
        "children" => [
          %{"trait_name" => "Yes"},
          %{"trait_name" => "Rather not", "is_skipped_tag" => true}
        ]
      })

    active = Enum.filter(created["children"], & &1["is_active"])
    rather = Enum.find(active, &(&1["trait_name"] == "Rather not"))

    assert length(active) == 2
    assert rather["is_skipped_tag"] == true
    refute Enum.any?(active, &(&1["trait_name"] == "Prefer not to say"))
  end

  test "zip parents are not given a skip child", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "force" => true,
        "parent" => %{
          "trait_name" => "Zip #{unique()}",
          "input_type" => "single_select_zip"
        },
        "survey_question" => %{"text" => "Zip?"},
        "children" => [%{"trait_name" => "00000"}]
      })

    refute Enum.any?(created["children"], & &1["is_skipped_tag"])
  end

  test "moves the skip answer onto another child and refuses to clear the last one", %{
    token: token
  } do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "parent" => %{
          "trait_name" => "Hobbies #{unique()}",
          "input_type" => "multi_select"
        },
        "survey_question" => %{"text" => "Hobbies?"},
        "children" => [
          %{"trait_name" => "Knitting"},
          %{"trait_name" => "Prefer not to say", "is_skipped_tag" => true}
        ]
      })

    knitting = Enum.find(created["children"], &(&1["trait_name"] == "Knitting"))
    prefer = Enum.find(created["children"], &(&1["trait_name"] == "Prefer not to say"))

    authed(token)
    |> patch(
      ~p"/api/admin/traits/#{created["id"]}/children/#{knitting["id"]}",
      Jason.encode!(%{"is_skipped_tag" => true})
    )
    |> json_response(200)

    assert Repo.get!(Trait, knitting["id"]).is_skipped_tag
    refute Repo.get!(Trait, prefer["id"]).is_skipped_tag

    refused =
      authed(token)
      |> patch(
        ~p"/api/admin/traits/#{created["id"]}/children/#{knitting["id"]}",
        Jason.encode!(%{"is_skipped_tag" => false})
      )
      |> json_response(422)

    assert refused["error"] == "invalid"
    assert Repo.get!(Trait, knitting["id"]).is_skipped_tag
  end

  test "refuses to mark a zip child as the skip answer", %{token: token} do
    created =
      api(token, :post, ~p"/api/admin/traits/design_packs", %{
        "mode" => "create",
        "force" => true,
        "parent" => %{
          "trait_name" => "Zip #{unique()}",
          "input_type" => "single_select_zip"
        },
        "survey_question" => %{"text" => "Zip?"},
        "children" => [%{"trait_name" => "00000"}]
      })

    child = Repo.get_by!(Trait, parent_trait_id: created["id"], trait_name: "00000")

    refused =
      authed(token)
      |> patch(
        ~p"/api/admin/traits/#{created["id"]}/children/#{child.id}",
        Jason.encode!(%{"is_skipped_tag" => true, "force" => true})
      )
      |> json_response(422)

    assert refused["error"] == "invalid"
    refute Repo.get!(Trait, child.id).is_skipped_tag
  end

  test "multi-select saves that mix the skip child with other answers conflict" do
    children = [
      %{id: 1, is_skipped_tag: false},
      %{id: 2, is_skipped_tag: true}
    ]

    trait = %{input_type: "multi_select", child_traits: children}

    assert Traits.mixed_skip_selection?(trait, [1, 2])
    assert Traits.mixed_skip_selection?(trait, ["2", "1"])
    refute Traits.mixed_skip_selection?(trait, [2])
    refute Traits.mixed_skip_selection?(trait, [1])

    refute Traits.mixed_skip_selection?(%{input_type: "single_select", child_traits: children}, [
             1,
             2
           ])
  end

  defp api(token, method, path, body) do
    conn =
      case method do
        :get -> get(authed(token), path)
        :post -> post(authed(token), path, Jason.encode!(body))
        :patch -> patch(authed(token), path, Jason.encode!(body))
      end

    json_response(conn, 200)
  end

  defp authed(token) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end

  defp user(role) do
    %User{}
    |> User.registration_changeset(%{"alias" => "api-#{role}-#{unique()}"})
    |> Ecto.Changeset.put_change(:role, role)
    |> Repo.insert!()
  end

  defp ensure_age_parent do
    case Repo.get(Trait, 93) do
      %Trait{parent_trait_id: nil} = trait ->
        trait

      nil ->
        Repo.insert!(%Trait{
          id: 93,
          trait_name: "Age",
          input_type: "single_select",
          display_order: 1,
          is_active: true,
          added_by: 0,
          modified_by: 0
        })
    end
  end

  defp unique, do: System.unique_integer([:positive])
end
