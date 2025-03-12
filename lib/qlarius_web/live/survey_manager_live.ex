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
      |> assign(:available_traits, [])
      |> assign(:page_title, "Survey Manager")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new ->
          category_id = params["category_id"]
          category = Surveys.get_survey_category!(category_id)
          survey = %Survey{category_id: category.id, display_order: 1}
          changeset = Surveys.change_survey(survey)

          socket
          |> assign(:survey, survey)
          |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
          |> assign(:form, to_form(changeset))

        :edit ->
          survey = Surveys.get_survey!(params["id"])
          changeset = Surveys.change_survey(survey)

          socket
          |> assign(:survey, survey)
          |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
          |> assign(:form, to_form(changeset))

        :show ->
          survey = Surveys.get_survey!(params["id"])
          available_traits = Traits.list_available_traits_by_category(params["id"])

          socket
          |> assign(:selected_survey, survey)
          |> assign(:available_traits, available_traits)

        :index ->
          socket
          |> assign(:survey, nil)
          |> assign(:form, nil)
          |> assign(:selected_survey, nil)
          |> assign(:available_traits, [])
      end

    {:noreply, socket}
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
        {:noreply, push_patch(socket, to: ~p"/survey_manager/#{survey_id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove trait from survey")}
    end
  end

  @impl true
  def handle_event("add_trait", %{"survey-id" => survey_id, "trait-id" => trait_id}, socket) do
    case Traits.add_trait_to_survey(survey_id, trait_id) do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: ~p"/survey_manager/#{survey_id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add trait to survey")}
    end
  end

  defp save_survey(socket, :new, survey_params) do
    case Surveys.create_survey(survey_params) do
      {:ok, survey} ->
        socket
        |> put_flash(:info, "Survey created successfully")
        |> push_patch(to: ~p"/survey_manager/#{survey.id}")

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
        |> push_patch(to: ~p"/survey_manager/#{updated_survey.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, changeset: changeset)
    end
  end
end
