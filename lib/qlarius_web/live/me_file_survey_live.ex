defmodule QlariusWeb.MeFileSurveyLive do
  use QlariusWeb, :live_view

  alias Qlarius.Surveys
  alias Qlarius.MeFile
  import QlariusWeb.TraitPanelComponent

  @impl true
  def mount(%{"survey_id" => survey_id}, _session, socket) do
    with {:ok, survey} <- fetch_survey(survey_id),
         traits <- Enum.sort_by(survey.traits, & &1.display_order) do
      current_trait = Enum.at(traits, 0)

      selected_values =
        if current_trait,
          do: MeFile.get_user_trait_values(current_trait.id, socket.assigns.current_user.id),
          else: []

      socket =
        socket
        |> assign(:survey, survey)
        |> assign(:traits, traits)
        |> assign(:current_trait_index, 0)
        |> assign(
          :completed_count,
          MeFile.count_completed_questions([survey], socket.assigns.current_user.id)
        )
        |> assign(:selected_values, selected_values)

      {:ok, socket}
    else
      {:error, :not_found} ->
        {:ok,
         socket |> put_flash(:error, "Survey not found") |> redirect(to: ~p"/me_file/surveys")}
    end
  end

  @impl true
  def handle_event("save_trait", %{"value" => value_id}, socket) do
    handle_trait_save(socket, [String.to_integer(value_id)])
  end

  def handle_event("save_trait", %{"values" => value_ids}, socket) do
    value_ids = Enum.map(value_ids, &String.to_integer/1)
    handle_trait_save(socket, value_ids)
  end

  def handle_event("done", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/me_file/surveys")}
  end

  defp handle_trait_save(socket, value_ids) do
    %{
      current_user: user,
      survey: survey,
      traits: traits,
      current_trait_index: index
    } = socket.assigns

    current_trait = Enum.at(traits, index)

    case MeFile.create_user_trait_values(user.id, current_trait.id, value_ids) do
      {:ok, _} ->
        socket =
          if index + 1 >= length(traits) do
            push_navigate(socket, to: ~p"/me_file/surveys")
          else
            next_trait = Enum.at(traits, index + 1)
            next_values = MeFile.get_user_trait_values(next_trait.id, user.id)

            socket
            |> assign(:current_trait_index, index + 1)
            |> assign(:completed_count, MeFile.count_completed_questions([survey], user.id))
            |> assign(:selected_values, next_values)
          end

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save answer")}
    end
  end

  defp fetch_survey(survey_id) do
    {:ok, Surveys.get_survey!(survey_id)}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end
end
