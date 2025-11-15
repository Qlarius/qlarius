defmodule Qlarius.YouData.SurveyManager do
  import Ecto.Query, warn: false

  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys.{Survey, SurveyCategory, SurveyQuestionSurvey}
  alias Qlarius.YouData.Traits.Trait

  def list_active_surveys(_scope, search \\ "") do
    base_query =
      from s in Survey,
        join: sc in assoc(s, :survey_category),
        where: s.active == true

    query =
      if search != "" do
        search_term = "%#{search}%"
        from [s, sc] in base_query, where: ilike(s.name, ^search_term)
      else
        base_query
      end

    query =
      from [s, sc] in query,
        order_by: [asc: sc.display_order, asc: sc.id, asc: s.display_order, asc: s.name],
        select: s,
        preload: [survey_category: sc]

    Repo.all(query)
  end

  def get_survey_with_details(_scope, id) do
    child_traits_query =
      from ct in Trait,
        order_by: [asc: ct.display_order, asc: ct.trait_name]

    survey =
      Repo.get!(Survey, id)
      |> Repo.preload([
        :survey_category,
        survey_question_surveys:
          from(sqs in SurveyQuestionSurvey,
            order_by: [asc: sqs.display_order],
            preload: [
              survey_question: [
                trait: [
                  :trait_category,
                  child_traits: ^child_traits_query
                ]
              ]
            ]
          )
      ])
      |> Repo.preload(
        survey_question_surveys: [
          survey_question: [
            trait: [
              child_traits: :survey_answer
            ]
          ]
        ]
      )

    survey
  end

  def list_survey_categories(_scope) do
    Repo.all(
      from sc in SurveyCategory,
        order_by: [asc: sc.display_order, asc: sc.survey_category_name]
    )
  end

  def list_available_questions(_scope, survey_id \\ nil) do
    used_question_ids =
      if survey_id do
        Repo.all(
          from sqs in SurveyQuestionSurvey,
            where: sqs.survey_id == ^survey_id,
            select: sqs.survey_question_id
        )
      else
        []
      end

    Repo.all(
      from t in Trait,
        where: is_nil(t.parent_trait_id),
        where: t.active == 1,
        where: not is_nil(t.trait_category_id),
        join: sq in assoc(t, :survey_question),
        join: tc in assoc(t, :trait_category),
        where: sq.id not in ^used_question_ids,
        order_by: [asc: tc.display_order, asc: t.display_order, asc: t.trait_name],
        select: t,
        preload: [trait_category: tc, survey_question: sq]
    )
  end

  def search_available_questions(_scope, survey_id, search) do
    used_question_ids =
      Repo.all(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id,
          select: sqs.survey_question_id
      )

    search_term = "%#{search}%"

    Repo.all(
      from t in Trait,
        where: is_nil(t.parent_trait_id),
        where: t.active == 1,
        where: not is_nil(t.trait_category_id),
        join: sq in assoc(t, :survey_question),
        join: tc in assoc(t, :trait_category),
        where: sq.id not in ^used_question_ids,
        where: ilike(t.trait_name, ^search_term) or ilike(sq.text, ^search_term),
        order_by: [asc: tc.display_order, asc: t.display_order, asc: t.trait_name],
        select: t,
        preload: [trait_category: tc, survey_question: sq]
    )
  end

  def create_survey(scope, attrs) do
    max_display_order =
      Repo.one(from s in Survey, select: max(s.display_order)) || 0

    attrs =
      attrs
      |> Map.put("display_order", max_display_order + 1)
      |> Map.put("created_by", scope.true_user.id)
      |> Map.put("updated_by", scope.true_user.id)

    %Survey{}
    |> Survey.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey(scope, %Survey{} = survey, attrs) do
    attrs = Map.put(attrs, "updated_by", scope.true_user.id)

    survey
    |> Survey.changeset(attrs)
    |> Repo.update()
  end

  def delete_survey(_scope, %Survey{} = survey) do
    Repo.transaction(fn ->
      Repo.delete_all(from sqs in SurveyQuestionSurvey, where: sqs.survey_id == ^survey.id)
      Repo.delete!(survey)
    end)
  end

  def add_question_to_survey(_scope, survey_id, survey_question_id) do
    max_display_order =
      Repo.one(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id,
          select: max(sqs.display_order)
      ) || 0

    %SurveyQuestionSurvey{}
    |> SurveyQuestionSurvey.changeset(%{
      survey_id: survey_id,
      survey_question_id: survey_question_id,
      display_order: max_display_order + 1
    })
    |> Repo.insert()
  end

  def remove_question_from_survey(_scope, survey_id, survey_question_id) do
    Repo.delete_all(
      from sqs in SurveyQuestionSurvey,
        where: sqs.survey_id == ^survey_id and sqs.survey_question_id == ^survey_question_id
    )

    reorder_questions_after_removal(survey_id)
  end

  defp reorder_questions_after_removal(survey_id) do
    questions =
      Repo.all(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id,
          order_by: [asc: sqs.display_order]
      )

    questions
    |> Enum.with_index(1)
    |> Enum.each(fn {question, new_order} ->
      question
      |> Ecto.Changeset.change(%{display_order: new_order})
      |> Repo.update!()
    end)
  end

  def move_question_up(_scope, survey_id, survey_question_id) do
    current =
      Repo.one!(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id and sqs.survey_question_id == ^survey_question_id
      )

    previous =
      Repo.one(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id,
          where: sqs.display_order < ^current.display_order,
          order_by: [desc: sqs.display_order],
          limit: 1
      )

    if previous do
      Repo.transaction(fn ->
        current
        |> Ecto.Changeset.change(%{display_order: previous.display_order})
        |> Repo.update!()

        previous
        |> Ecto.Changeset.change(%{display_order: current.display_order})
        |> Repo.update!()
      end)
    else
      {:error, :already_first}
    end
  end

  def move_question_down(_scope, survey_id, survey_question_id) do
    current =
      Repo.one!(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id and sqs.survey_question_id == ^survey_question_id
      )

    next =
      Repo.one(
        from sqs in SurveyQuestionSurvey,
          where: sqs.survey_id == ^survey_id,
          where: sqs.display_order > ^current.display_order,
          order_by: [asc: sqs.display_order],
          limit: 1
      )

    if next do
      Repo.transaction(fn ->
        current
        |> Ecto.Changeset.change(%{display_order: next.display_order})
        |> Repo.update!()

        next
        |> Ecto.Changeset.change(%{display_order: current.display_order})
        |> Repo.update!()
      end)
    else
      {:error, :already_last}
    end
  end
end
