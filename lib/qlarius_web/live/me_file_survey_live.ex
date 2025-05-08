defmodule QlariusWeb.MeFileSurveyLive do
  use QlariusWeb, :live_view

  alias Qlarius.Surveys
  alias Qlarius.Traits
  alias Qlarius.Traits.Trait

  import QlariusWeb.TraitPanelComponent

  @impl true
  def mount(%{"survey_id" => survey_id}, _session, socket) do
    {:ok, survey} = {:ok, Surveys.get_survey!(survey_id)}
    traits = Enum.sort_by(survey.traits, & &1.display_order)

    socket
    |> assign(:survey, survey)
    |> assign(:traits, traits)
    |> ok()
  end

  @impl true
  def handle_params(params, _uri, socket) do
    index = params |> Map.get("index", "0") |> String.to_integer()

    %{survey: survey, traits: traits} = socket.assigns

    current_trait = %Trait{} = Enum.at(traits, index)

    selected_values =
      Traits.get_user_trait_values(current_trait.id, socket.assigns.current_scope.user.id)

    completed_count =
      Surveys.count_completed_questions([survey], socket.assigns.current_scope.user.id)

    socket
    |> assign(
      completed_count: completed_count,
      current_trait_index: index,
      selected_values: selected_values
    )
    |> noreply()
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
      current_scope: %{user: user},
      survey: survey,
      traits: traits,
      current_trait_index: index
    } = socket.assigns

    current_trait = Enum.at(traits, index)

    case Traits.create_user_trait_values(user.id, current_trait.id, value_ids) do
      {:ok, _} ->
        if index + 1 >= length(traits) do
          push_navigate(socket, to: ~p"/me_file/surveys")
        else
          push_patch(socket, to: ~p"/me_file/surveys/#{survey}/#{index + 1}")
        end

      {:error, _} ->
        put_flash(socket, :error, "Failed to save answer")
    end
    |> noreply()
  end

  defp index_badge(assigns) do
    ~H"""
    <.link
      patch={@link}
      class={[
        "h-2 w-2 rounded-full mx-1",
        if(@completed, do: "bg-green-500", else: "bg-gray-300"),
        if(@current, do: "scale-150 origin-center")
      ]}
    >
    </.link>
    """
  end
end
