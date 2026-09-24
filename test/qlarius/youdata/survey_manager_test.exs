defmodule Qlarius.YouData.SurveyManagerTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.YouData.SurveyManager
  alias Qlarius.YouData.Surveys.{Survey, SurveyCategory}

  test "active surveys without a category lead the list as uncategorized" do
    category =
      %SurveyCategory{}
      |> SurveyCategory.changeset(%{survey_category_name: "Lifestyle #{unique()}"})
      |> Repo.insert!()

    categorized =
      survey(%{name: "Categorized #{unique()}", survey_category_id: category.id, active: true})

    uncategorized = survey(%{name: "Loose #{unique()}", active: true})
    inactive = survey(%{name: "Hidden #{unique()}", active: false})

    listed = SurveyManager.list_active_surveys(nil)
    ids = Enum.map(listed, & &1.id)

    assert Enum.find_index(ids, &(&1 == uncategorized.id)) <
             Enum.find_index(ids, &(&1 == categorized.id))

    assert Enum.any?(listed, &(&1.id == uncategorized.id and is_nil(&1.survey_category)))
    refute inactive.id in ids
  end

  defp survey(attrs) do
    %Survey{}
    |> Survey.changeset(Map.merge(%{created_by: 1, updated_by: 1, display_order: 1}, attrs))
    |> Repo.insert!()
  end

  defp unique, do: System.unique_integer([:positive])
end
