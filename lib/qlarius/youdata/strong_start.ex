defmodule Qlarius.YouData.StrongStart do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.System
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.AdEvent

  @doc """
  Returns progress information for the strong start checklist.
  """
  def get_progress(me_file, trait_count) do
    me_file = Repo.preload(me_file, :user)

    tag_goal = System.get_global_variable_int("STRONG_START_TAG_GOAL", 25)
    survey_progress = get_survey_progress(me_file)

    steps = %{
      essentials_survey_completed: essentials_survey_completed?(me_file),
      first_ad_interacted: first_ad_interacted?(me_file),
      notifications_configured: notifications_configured?(me_file),
      tags_25_reached: tags_goal_reached?(trait_count, tag_goal),
      referral_viewed: referral_viewed?(me_file)
    }

    completed_count = Enum.count(steps, fn {_key, completed} -> completed end)
    total_count = map_size(steps)

    %{
      steps: steps,
      completed_count: completed_count,
      total_count: total_count,
      percentage: round(completed_count / total_count * 100),
      tag_count: trait_count,
      tag_goal: tag_goal,
      survey_answered: survey_progress.answered,
      survey_total: survey_progress.total
    }
  end

  @doc """
  Marks a specific step as complete in the strong_start_data field.
  """
  def mark_step_complete(me_file, step_name) do
    current_data = me_file.strong_start_data || %{}
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    updated_data =
      current_data
      |> Map.put(step_name, true)
      |> Map.update("completed_at_timestamps", %{step_name => timestamp}, fn timestamps ->
        Map.put(timestamps, step_name, timestamp)
      end)

    me_file
    |> MeFile.changeset(%{strong_start_data: updated_data})
    |> maybe_mark_fully_completed()
    |> Repo.update()
  end

  @doc """
  Marks the strong start as skipped forever.
  """
  def skip_forever(me_file) do
    me_file
    |> MeFile.changeset(%{
      strong_start_status: "skipped",
      strong_start_completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Dismisses the strong start reminder temporarily (until next login).
  """
  def remind_later(me_file) do
    me_file
    |> MeFile.changeset(%{strong_start_status: "dismissed"})
    |> Repo.update()
  end

  @doc """
  Determines if the strong start checklist should be displayed.
  """
  def should_show?(me_file) do
    case me_file.strong_start_status do
      "skipped" ->
        false

      "dismissed" ->
        false

      "completed" ->
        display_hours = System.get_global_variable_int("STRONG_START_DISPLAY_HOURS", 24)

        if me_file.strong_start_completed_at do
          completed_at = DateTime.from_naive!(me_file.strong_start_completed_at, "Etc/UTC")
          hours_since_completion = DateTime.diff(DateTime.utc_now(), completed_at, :hour)
          hours_since_completion < display_hours
        else
          true
        end

      _ ->
        true
    end
  end

  @doc """
  Calculates completion percentage (0-100).
  """
  def calculate_completion_percentage(me_file) do
    trait_count = MeFile.trait_tag_count(me_file)
    progress = get_progress(me_file, trait_count)
    progress.percentage
  end

  defp essentials_survey_completed?(me_file) do
    data = me_file.strong_start_data || %{}

    if Map.get(data, "essentials_survey_completed", false) do
      true
    else
      survey_id = System.get_global_variable_int("STRONG_START_SURVEY_ID", nil)

      if survey_id do
        parent_traits = Qlarius.YouData.Surveys.parent_traits_for_survey_ordered(survey_id)
        total_questions = length(parent_traits)

        if total_questions == 0 do
          false
        else
          answered_questions =
            Enum.count(parent_traits, fn {parent_trait_id, _name, _order} ->
              query =
                from mft in Qlarius.YouData.MeFiles.MeFileTag,
                  join: t in Qlarius.YouData.Traits.Trait,
                  on: mft.trait_id == t.id,
                  where: mft.me_file_id == ^me_file.id and t.parent_trait_id == ^parent_trait_id

              Repo.exists?(query)
            end)

          answered_questions == total_questions
        end
      else
        false
      end
    end
  end

  defp first_ad_interacted?(me_file) do
    query =
      from ae in AdEvent,
        where: ae.me_file_id == ^me_file.id,
        limit: 1

    Repo.exists?(query)
  end

  defp notifications_configured?(me_file) do
    data = me_file.strong_start_data || %{}
    Map.get(data, "notifications_configured", false)
  end

  defp tags_goal_reached?(trait_count, tag_goal) do
    trait_count >= tag_goal
  end

  defp referral_viewed?(me_file) do
    data = me_file.strong_start_data || %{}
    Map.get(data, "referral_viewed", false)
  end

  defp get_survey_progress(me_file) do
    survey_id = System.get_global_variable_int("STRONG_START_SURVEY_ID", nil)

    if survey_id do
      parent_traits = Qlarius.YouData.Surveys.parent_traits_for_survey_ordered(survey_id)
      total_questions = length(parent_traits)

      if total_questions == 0 do
        %{answered: 0, total: 0}
      else
        answered_questions =
          Enum.count(parent_traits, fn {parent_trait_id, _name, _order} ->
            query =
              from mft in Qlarius.YouData.MeFiles.MeFileTag,
                join: t in Qlarius.YouData.Traits.Trait,
                on: mft.trait_id == t.id,
                where: mft.me_file_id == ^me_file.id and t.parent_trait_id == ^parent_trait_id

            Repo.exists?(query)
          end)

        %{answered: answered_questions, total: total_questions}
      end
    else
      %{answered: 0, total: 0}
    end
  end

  defp maybe_mark_fully_completed(changeset) do
    me_file = changeset.data
    trait_count = MeFile.trait_tag_count(me_file)
    progress = get_progress(me_file, trait_count)

    if progress.completed_count == progress.total_count && is_nil(me_file.strong_start_completed_at) do
      changeset
      |> Ecto.Changeset.put_change(:strong_start_status, "completed")
      |> Ecto.Changeset.put_change(
        :strong_start_completed_at,
        DateTime.utc_now() |> DateTime.truncate(:second)
      )
    else
      changeset
    end
  end
end
