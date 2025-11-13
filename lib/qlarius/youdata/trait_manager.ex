defmodule Qlarius.YouData.TraitManager do
  import Ecto.Query, warn: false

  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}
  alias Qlarius.YouData.Surveys.{SurveyQuestion, SurveyAnswer}

  def list_parent_traits(_scope, search \\ "") do
    query =
      from t in Trait,
        where: is_nil(t.parent_trait_id),
        where: t.active == 1,
        order_by: [asc: t.display_order, asc: t.trait_name],
        preload: [:trait_category]

    query =
      if search != "" do
        search_term = "%#{search}%"
        from t in query, where: ilike(t.trait_name, ^search_term)
      else
        query
      end

    Repo.all(query)
  end

  def get_parent_trait_with_details(_scope, id) do
    parent =
      Repo.get!(Trait, id)
      |> Repo.preload([
        :trait_category,
        :survey_question,
        child_traits: from(t in Trait, order_by: [asc: t.display_order, asc: t.trait_name])
      ])

    children_with_stats =
      Enum.map(parent.child_traits, fn child ->
        stats = get_trait_stats(child.id)

        Map.merge(child, %{
          tags_count: stats.tags_count,
          grps_count: stats.grps_count,
          survey_answer: get_survey_answer_for_trait(child.id)
        })
      end)

    Map.put(parent, :child_traits, children_with_stats)
  end

  defp get_survey_answer_for_trait(trait_id) do
    Repo.one(from sa in SurveyAnswer, where: sa.trait_id == ^trait_id)
  end

  def get_trait_stats(trait_id) do
    tags_count =
      Repo.one(
        from mft in "me_file_tags",
          where: mft.trait_id == ^trait_id,
          select: count(mft.id)
      ) || 0

    grps_count =
      Repo.one(
        from tgt in "trait_group_traits",
          where: tgt.trait_id == ^trait_id,
          select: count(tgt.id)
      ) || 0

    %{tags_count: tags_count, grps_count: grps_count}
  end

  def list_trait_categories(_scope) do
    Repo.all(from tc in TraitCategory, order_by: [asc: tc.display_order, asc: tc.name])
  end

  def create_parent_trait(scope, attrs) do
    max_display_order =
      Repo.one(
        from t in Trait,
          where: is_nil(t.parent_trait_id),
          select: max(t.display_order)
      ) || 0

    attrs =
      attrs
      |> Map.put("display_order", max_display_order + 1)
      |> Map.put("active", 1)
      |> Map.put("is_taggable", 1)
      |> Map.put("is_campaign_only", false)
      |> Map.put("is_numeric", false)
      |> Map.put("added_by", scope.true_user.id)
      |> Map.put("modified_by", scope.true_user.id)

    %Trait{}
    |> Trait.changeset(attrs)
    |> Repo.insert()
  end

  def update_parent_trait(scope, %Trait{} = trait, attrs) do
    attrs = Map.put(attrs, "modified_by", scope.true_user.id)

    trait
    |> Trait.changeset(attrs)
    |> Repo.update()
  end

  def update_child_trait(scope, %Trait{} = trait, attrs) do
    attrs = Map.put(attrs, "modified_by", scope.true_user.id)

    trait
    |> Trait.changeset(attrs)
    |> Repo.update()
  end

  def can_delete_trait?(%Trait{} = trait) do
    trait = Repo.preload(trait, :child_traits)

    stats = get_trait_stats(trait.id)

    children_have_associations =
      Enum.any?(trait.child_traits, fn child ->
        child_stats = get_trait_stats(child.id)
        child_stats.tags_count > 0 || child_stats.grps_count > 0
      end)

    stats.tags_count == 0 && stats.grps_count == 0 && !children_have_associations
  end

  def delete_parent_trait(_scope, %Trait{} = trait) do
    if can_delete_trait?(trait) do
      trait = Repo.preload(trait, [:child_traits, :survey_question])

      Repo.transaction(fn ->
        if trait.survey_question do
          Repo.delete_all(
            from sa in SurveyAnswer, where: sa.survey_question_id == ^trait.survey_question.id
          )

          Repo.delete!(trait.survey_question)
        end

        Enum.each(trait.child_traits, fn child ->
          Repo.delete!(child)
        end)

        Repo.delete!(trait)
      end)
    else
      {:error, :has_associations}
    end
  end

  def delete_child_trait(_scope, %Trait{} = trait) do
    stats = get_trait_stats(trait.id)

    if stats.tags_count == 0 && stats.grps_count == 0 do
      Repo.transaction(fn ->
        Repo.delete_all(from sa in SurveyAnswer, where: sa.trait_id == ^trait.id)
        Repo.delete!(trait)
      end)
    else
      {:error, :has_associations}
    end
  end

  def batch_create_child_traits(scope, %Trait{} = parent_trait, names_text) do
    parent_trait = Repo.preload(parent_trait, :child_traits)

    max_display_order =
      case parent_trait.child_traits do
        [] ->
          0

        children ->
          Enum.map(children, & &1.display_order) |> Enum.max()
      end

    trait_names =
      names_text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    results =
      trait_names
      |> Enum.with_index(1)
      |> Enum.map(fn {name, index} ->
        attrs = %{
          "trait_name" => name,
          "parent_trait_id" => parent_trait.id,
          "trait_category_id" => parent_trait.trait_category_id,
          "input_type" => parent_trait.input_type,
          "is_taggable" => parent_trait.is_taggable,
          "active" => 1,
          "is_campaign_only" => false,
          "is_numeric" => false,
          "display_order" => max_display_order + index,
          "added_by" => scope.true_user.id,
          "modified_by" => scope.true_user.id
        }

        %Trait{}
        |> Trait.changeset(attrs)
        |> Repo.insert()
      end)

    created_count = Enum.count(results, &match?({:ok, _}, &1))
    failed_count = Enum.count(results, &match?({:error, _}, &1))

    {:ok, %{created: created_count, failed: failed_count}}
  end

  def create_survey_question(scope, %Trait{} = parent_trait, attrs) do
    parent_trait = Repo.preload(parent_trait, :child_traits)

    attrs =
      attrs
      |> Map.put("trait_id", parent_trait.id)
      |> Map.put("active", "1")
      |> Map.put("display_order", 1)
      |> Map.put("added_by", scope.true_user.id)
      |> Map.put("modified_by", scope.true_user.id)

    Repo.transaction(fn ->
      case %SurveyQuestion{}
           |> SurveyQuestion.changeset(attrs)
           |> Repo.insert() do
        {:ok, survey_question} ->
          Enum.each(parent_trait.child_traits, fn child ->
            create_survey_answer_for_child(scope, survey_question, child)
          end)

          survey_question

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_survey_answer_for_child(scope, survey_question, child_trait) do
    max_display_order =
      Repo.one(
        from sa in SurveyAnswer,
          where: sa.survey_question_id == ^survey_question.id,
          select: max(sa.display_order)
      ) || 0

    attrs = %{
      "text" => child_trait.trait_name,
      "survey_question_id" => survey_question.id,
      "trait_id" => child_trait.id,
      "display_order" => max_display_order + 1,
      "added_by" => scope.true_user.id,
      "modified_by" => scope.true_user.id
    }

    %SurveyAnswer{}
    |> SurveyAnswer.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey_question(scope, %SurveyQuestion{} = question, attrs) do
    attrs = Map.put(attrs, "modified_by", scope.true_user.id)

    question
    |> SurveyQuestion.changeset(attrs)
    |> Repo.update()
  end

  def create_survey_answers_for_missing_children(scope, %Trait{} = parent_trait) do
    parent_trait = Repo.preload(parent_trait, [:survey_question, :child_traits])

    if parent_trait.survey_question do
      existing_answer_trait_ids =
        Repo.all(
          from sa in SurveyAnswer,
            where: sa.survey_question_id == ^parent_trait.survey_question.id,
            select: sa.trait_id
        )

      children_without_answers =
        Enum.reject(parent_trait.child_traits, fn child ->
          child.id in existing_answer_trait_ids
        end)

      created_count =
        Enum.reduce(children_without_answers, 0, fn child, acc ->
          case create_survey_answer_for_child(scope, parent_trait.survey_question, child) do
            {:ok, _} -> acc + 1
            {:error, _} -> acc
          end
        end)

      {:ok, created_count}
    else
      {:error, :no_survey_question}
    end
  end

  def get_survey_answer!(_scope, id) do
    Repo.get!(SurveyAnswer, id)
    |> Repo.preload(survey_question: [trait: :child_traits])
  end

  def update_survey_answer(scope, %SurveyAnswer{} = answer, attrs) do
    attrs = Map.put(attrs, "modified_by", scope.true_user.id)

    answer
    |> SurveyAnswer.changeset(attrs)
    |> Repo.update()
  end

  def get_child_trait!(_scope, id) do
    Repo.get!(Trait, id)
  end

  def restripe_child_display_order(scope, %Trait{} = parent_trait) do
    parent_trait = Repo.preload(parent_trait, :child_traits)

    sorted_children =
      parent_trait.child_traits
      |> Enum.sort_by(&{&1.display_order, &1.trait_name})

    Repo.transaction(fn ->
      sorted_children
      |> Enum.with_index(1)
      |> Enum.each(fn {child, new_order} ->
        child
        |> Ecto.Changeset.change(%{
          display_order: new_order,
          modified_by: scope.true_user.id
        })
        |> Repo.update!()
      end)
    end)
  end
end
