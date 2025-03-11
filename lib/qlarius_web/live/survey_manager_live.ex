defmodule QlariusWeb.SurveyManagerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Surveys
  alias Qlarius.Surveys.Survey

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
  end

  defp apply_action(socket, :new, %{"category_id" => category_id}) do
    category = Surveys.get_survey_category!(category_id)
    
    socket
    |> assign(:survey, %Survey{category_id: category.id, display_order: 1})
    |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    survey = Surveys.get_survey!(id)
    
    socket
    |> assign(:survey, survey)
    |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
  end

  @impl true
  def handle_event("select_survey", %{"id" => id}, socket) do
    survey = Surveys.get_survey!(id)
    
    {:noreply, assign(socket, :selected_survey, survey)}
  end

  @impl true
  def handle_event("add_survey", %{"category_id" => category_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/survey_manager/new/#{category_id}")}
  end

  @impl true
  def handle_event("edit_survey", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/survey_manager/edit/#{id}")}
  end

  @impl true
  def handle_event("save", %{"survey" => survey_params}, socket) do
    # Convert string keys to atoms
    params = for {key, val} <- survey_params, into: %{} do
      {String.to_existing_atom(key), val}
    end
    save_survey(socket, socket.assigns.live_action, params)
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/survey_manager")}
  end

  defp save_survey(socket, :new, survey_params) do
    case Surveys.create_survey(survey_params) do
      {:ok, survey} ->
        socket = 
          socket
          |> put_flash(:info, "Survey created successfully")
          |> push_patch(to: ~p"/survey_manager")
          |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
          |> assign(:selected_survey, survey)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_survey(socket, :edit, survey_params) do
    survey = socket.assigns.survey

    case Surveys.update_survey(survey, survey_params) do
      {:ok, updated_survey} ->
        socket = 
          socket
          |> put_flash(:info, "Survey updated successfully")
          |> push_patch(to: ~p"/survey_manager")
          |> assign(:categories_with_surveys, Surveys.list_surveys_by_category())
          |> assign(:selected_survey, updated_survey)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
