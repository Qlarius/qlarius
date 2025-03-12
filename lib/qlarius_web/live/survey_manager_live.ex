defmodule QlariusWeb.SurveyManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Surveys
  alias Qlarius.Surveys.Survey
  alias Qlarius.Traits

  @impl true
  def mount(_params, _session, socket) do
    categories_with_surveys = Surveys.list_surveys_by_category()

    socket =
      socket
      |> assign(:categories_with_surveys, categories_with_surveys)
      |> assign(:selected_survey, nil)
      |> assign(:page_title, "Survey Manager")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:survey, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, %{"category_id" => category_id}) do
    category = Surveys.get_survey_category!(category_id)
    survey = %Survey{category_id: category.id, display_order: 1}
    changeset = Surveys.change_survey(survey)

    socket
    |> assign(:survey, survey)
    |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    survey = Surveys.get_survey!(id)
    changeset = Surveys.change_survey(survey)

    socket
    |> assign(:survey, survey)
    |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("select_survey", %{"id" => id}, socket) do
    survey = Surveys.get_survey!(id)
    {:noreply, assign(socket, :selected_survey, survey)}
  end

  @impl true
  def handle_event("save_survey", %{"survey" => survey_params}, socket) do
    socket
    |> save_survey(socket.assigns.live_action, survey_params)
    |> noreply()
  end

  @impl true
  def handle_event("validate_survey", %{"survey" => survey_params}, socket) do
    changeset = Surveys.change_survey(socket.assigns.survey, survey_params)

    socket
    |> assign(form: to_form(changeset, action: :validate))
    |> noreply()
  end

  @impl true
  def handle_event("remove_trait", %{"survey-id" => survey_id, "trait-id" => trait_id}, socket) do
    survey = Surveys.get_survey!(survey_id)
    trait = Traits.get_trait!(trait_id)

    case Traits.remove_trait_from_survey(survey, trait) do
      {:ok, _} ->
        updated_survey = Surveys.get_survey!(survey_id)
        {:noreply, assign(socket, :selected_survey, updated_survey)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove trait from survey")}
    end
  end

  defp save_survey(socket, :new, survey_params) do
    case Surveys.create_survey(survey_params) do
      {:ok, survey} ->
        socket
        |> put_flash(:info, "Survey created successfully")
        |> push_patch(to: ~p"/survey_manager")
        |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
        |> assign(:selected_survey, survey)

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, changeset: changeset)
    end
  end

  defp save_survey(socket, :edit, survey_params) do
    survey = socket.assigns.survey

    case Surveys.update_survey(survey, survey_params) do
      {:ok, updated_survey} ->
        socket
        |> put_flash(:info, "Survey updated successfully")
        |> push_patch(to: ~p"/survey_manager")
        |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
        |> assign(:selected_survey, updated_survey)

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, changeset: changeset)
    end
  end
end
