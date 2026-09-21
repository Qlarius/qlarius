defmodule QlariusWeb.Api.Admin.SurveyController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.SurveyManager
  alias Qlarius.YouData.TraitManager
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    surveys = SurveyManager.list_surveys(conn.assigns.current_scope, params["q"] || "")
    json(conn, %{surveys: Enum.map(surveys, &survey_json/1)})
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope

    case SurveyManager.create_survey(scope, params,
           keep_display_order: is_integer(params["display_order"]),
           keep_active: Map.has_key?(params, "active")
         ) do
      {:ok, survey} ->
        {:ok, survey} = SurveyManager.fetch_survey(scope, survey.id)

        conn
        |> put_status(201)
        |> json(survey_json(survey))

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, survey} <- SurveyManager.fetch_survey(scope, id),
         {:ok, survey} <- SurveyManager.update_survey(scope, survey, params),
         {:ok, survey} <- SurveyManager.fetch_survey(scope, survey.id) do
      json(conn, survey_json(survey))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def add_question(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    question_id = params["survey_question_id"]

    if question_id in [nil, ""] do
      Responder.error(conn, :survey_question_required)
    else
      case SurveyManager.place_question(scope, id, question_id, integer(params["display_order"])) do
        {:ok, _} ->
          {:ok, survey} = SurveyManager.fetch_survey(scope, id)
          json(conn, survey_json(survey))

        {:error, reason} ->
          Responder.error(conn, reason)
      end
    end
  end

  def remove_question(conn, %{"id" => id, "question_id" => question_id}) do
    SurveyManager.remove_question_from_survey(conn.assigns.current_scope, id, question_id)
    send_resp(conn, 204, "")
  end

  def update_question(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    question = Qlarius.Repo.get(Qlarius.YouData.Surveys.SurveyQuestion, id)

    if question do
      case TraitManager.update_survey_question(scope, question, %{"text" => params["text"]}) do
        {:ok, question} ->
          json(conn, %{id: question.id, text: question.text, trait_id: question.trait_id})

        {:error, reason} ->
          Responder.error(conn, reason)
      end
    else
      Responder.error(conn, :not_found)
    end
  end

  def update_answer(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    try do
      answer = TraitManager.get_survey_answer!(scope, id)

      case TraitManager.update_survey_answer(scope, answer, %{"text" => params["text"]}) do
        {:ok, answer} ->
          json(conn, %{id: answer.id, text: answer.text, trait_id: answer.trait_id})

        {:error, reason} ->
          Responder.error(conn, reason)
      end
    rescue
      Ecto.NoResultsError -> Responder.error(conn, :not_found)
    end
  end

  defp survey_json(survey) do
    %{
      id: survey.id,
      name: survey.name,
      active: survey.active,
      display_order: survey.display_order,
      survey_category_id: survey.survey_category_id,
      questions:
        Enum.map(survey.survey_question_surveys || [], fn join ->
          question = join.survey_question

          %{
            id: question.id,
            text: question.text,
            trait_id: question.trait_id,
            display_order: join.display_order
          }
        end)
    }
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
