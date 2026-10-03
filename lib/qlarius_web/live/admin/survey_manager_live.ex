defmodule QlariusWeb.Admin.SurveyManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.YouData.SurveyManager
  alias Qlarius.YouData.Surveys.Survey

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Survey Manager")
     |> assign(:search_query, "")
     |> assign(:surveys, SurveyManager.list_active_surveys(scope, ""))
     |> assign(:survey_categories, SurveyManager.list_survey_categories(scope))
     |> assign(:selected_survey, nil)
     |> assign(:editor_mode, nil)
     |> assign(:editing_survey, nil)
     |> assign(:form, nil)
     |> assign(:available_questions, [])
     |> assign(:available_search, "")
     |> assign(:expanded_questions, MapSet.new())}
  end

  def handle_event("search", %{"search" => search_query}, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:surveys, SurveyManager.list_active_surveys(scope, search_query))}
  end

  def handle_event("clear_search", _params, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:surveys, SurveyManager.list_active_surveys(scope, ""))}
  end

  def handle_event("select_survey", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    survey = SurveyManager.get_survey_with_details(scope, id)
    available_questions = SurveyManager.list_available_questions(scope, survey.id)

    {:noreply,
     socket
     |> assign(:selected_survey, survey)
     |> assign(:editor_mode, nil)
     |> assign(:editing_survey, nil)
     |> assign(:form, nil)
     |> assign(:available_questions, available_questions)
     |> assign(:available_search, "")
     |> assign(:expanded_questions, MapSet.new())}
  end

  def handle_event("new_survey", _params, socket) do
    changeset = Survey.changeset(%Survey{}, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :new_survey)
     |> assign(:editing_survey, nil)
     |> assign(:form, to_form(changeset))
     |> assign(:available_questions, [])
     |> assign(:available_search, "")}
  end

  def handle_event("edit_survey", _params, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey
    changeset = Survey.changeset(survey, %{})

    available_questions = SurveyManager.list_available_questions(scope, survey.id)

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_survey)
     |> assign(:editing_survey, survey)
     |> assign(:form, to_form(changeset))
     |> assign(:available_questions, available_questions)
     |> assign(:available_search, "")}
  end

  def handle_event("save_survey", %{"survey" => survey_params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.editor_mode do
        :new_survey ->
          SurveyManager.create_survey(scope, survey_params)

        :edit_survey ->
          SurveyManager.update_survey(scope, socket.assigns.editing_survey, survey_params)
      end

    case result do
      {:ok, survey} ->
        updated_survey = SurveyManager.get_survey_with_details(scope, survey.id)
        available_questions = SurveyManager.list_available_questions(scope, survey.id)

        {:noreply,
         socket
         |> put_flash(:info, "Survey saved successfully.")
         |> assign(
           :surveys,
           SurveyManager.list_active_surveys(scope, socket.assigns.search_query)
         )
         |> assign(:selected_survey, updated_survey)
         |> assign(:available_questions, available_questions)
         |> assign(:available_search, "")
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_survey", _params, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    case SurveyManager.delete_survey(scope, survey) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey deleted successfully.")
         |> assign(
           :surveys,
           SurveyManager.list_active_surveys(scope, socket.assigns.search_query)
         )
         |> assign(:selected_survey, nil)
         |> assign(:editor_mode, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete survey.")}
    end
  end

  def handle_event("search_available", %{"search" => search}, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    available_questions =
      if search == "" do
        SurveyManager.list_available_questions(scope, survey.id)
      else
        SurveyManager.search_available_questions(scope, survey.id, search)
      end

    {:noreply,
     socket
     |> assign(:available_search, search)
     |> assign(:available_questions, available_questions)}
  end

  def handle_event("clear_available_search", _params, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    {:noreply,
     socket
     |> assign(:available_search, "")
     |> assign(:available_questions, SurveyManager.list_available_questions(scope, survey.id))}
  end

  def handle_event("add_question", %{"question_id" => question_id}, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    case SurveyManager.add_question_to_survey(scope, survey.id, String.to_integer(question_id)) do
      {:ok, _} ->
        updated_survey = SurveyManager.get_survey_with_details(scope, survey.id)

        available_questions =
          if socket.assigns.available_search == "" do
            SurveyManager.list_available_questions(scope, survey.id)
          else
            SurveyManager.search_available_questions(
              scope,
              survey.id,
              socket.assigns.available_search
            )
          end

        {:noreply,
         socket
         |> assign(:selected_survey, updated_survey)
         |> assign(:available_questions, available_questions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add question to survey.")}
    end
  end

  def handle_event("remove_question", %{"question_id" => question_id}, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    SurveyManager.remove_question_from_survey(scope, survey.id, String.to_integer(question_id))

    updated_survey = SurveyManager.get_survey_with_details(scope, survey.id)

    available_questions =
      if socket.assigns.available_search == "" do
        SurveyManager.list_available_questions(scope, survey.id)
      else
        SurveyManager.search_available_questions(
          scope,
          survey.id,
          socket.assigns.available_search
        )
      end

    {:noreply,
     socket
     |> assign(:selected_survey, updated_survey)
     |> assign(:available_questions, available_questions)}
  end

  def handle_event("move_up", %{"question_id" => question_id}, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    SurveyManager.move_question_up(scope, survey.id, String.to_integer(question_id))

    updated_survey = SurveyManager.get_survey_with_details(scope, survey.id)

    {:noreply, assign(socket, :selected_survey, updated_survey)}
  end

  def handle_event("move_down", %{"question_id" => question_id}, socket) do
    scope = socket.assigns.current_scope
    survey = socket.assigns.selected_survey

    SurveyManager.move_question_down(scope, survey.id, String.to_integer(question_id))

    updated_survey = SurveyManager.get_survey_with_details(scope, survey.id)

    {:noreply, assign(socket, :selected_survey, updated_survey)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editor_mode, nil)
     |> assign(:editing_survey, nil)
     |> assign(:form, nil)}
  end

  def handle_event("toggle_question_answers", %{"question_id" => question_id}, socket) do
    question_id = String.to_integer(question_id)
    expanded = socket.assigns.expanded_questions

    expanded =
      if MapSet.member?(expanded, question_id) do
        MapSet.delete(expanded, question_id)
      else
        MapSet.put(expanded, question_id)
      end

    {:noreply, assign(socket, :expanded_questions, expanded)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-[1600px]">
              <.page_header
                title="Survey manager"
                subtitle="Pick a survey to order its questions, or add questions from the catalog."
              >
                <:actions>
                  <button type="button" phx-click="new_survey" class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="size-4" /> New survey
                  </button>
                </:actions>
              </.page_header>

              <div class="grid items-start gap-6 lg:grid-cols-12">
                <.panel flush title="Surveys" class="min-w-0 lg:col-span-3">
                  <div class="border-b border-base-300 px-4 py-3">
                    <.search_field
                      value={@search_query}
                      placeholder="Search surveys"
                      name="search"
                      class="w-full"
                    />
                  </div>

                  <div class="max-h-[600px] overflow-y-auto py-2">
                    <p
                      :if={@surveys == []}
                      class="px-6 py-4 text-center text-sm text-base-content/60"
                    >
                      No surveys found
                    </p>
                    <div
                      :for={surveys <- Enum.chunk_by(@surveys, & &1.survey_category_id)}
                      class="mb-2"
                    >
                      <p class="px-4 pt-2 pb-1 text-xs font-medium text-base-content/50">
                        {category_name(hd(surveys))}
                      </p>
                      <button
                        :for={survey <- surveys}
                        type="button"
                        phx-click="select_survey"
                        phx-value-id={survey.id}
                        class={[
                          "flex w-full items-center justify-between gap-2 px-4 py-2 text-left text-sm transition-colors",
                          if(@selected_survey && @selected_survey.id == survey.id,
                            do: "bg-primary/10 font-medium text-primary",
                            else: "hover:bg-base-200/60"
                          )
                        ]}
                      >
                        <span class="flex-1 truncate">{survey.name}</span>
                        <.icon name="hero-chevron-right" class="size-4 text-base-content/40" />
                      </button>
                    </div>
                  </div>
                </.panel>

                <div class="min-w-0 lg:col-span-6">
                  <%= if @selected_survey do %>
                    <.panel
                      flush
                      title={@selected_survey.name}
                      description={"#{category_name(@selected_survey)} · #{length(@selected_survey.survey_question_surveys)} questions"}
                    >
                      <:actions>
                        <.icon_button
                          icon="hero-pencil-square"
                          label="Edit survey"
                          phx-click="edit_survey"
                        />
                      </:actions>

                      <.empty_state
                        :if={@selected_survey.survey_question_surveys == []}
                        icon="hero-question-mark-circle"
                        title="No questions in this survey yet"
                      >
                        Add questions from the catalog on the right.
                      </.empty_state>

                      <ul
                        :if={@selected_survey.survey_question_surveys != []}
                        class="divide-y divide-base-300"
                      >
                        <li
                          :for={
                            {sqs, index} <- Enum.with_index(@selected_survey.survey_question_surveys)
                          }
                          class="flex items-start gap-3 px-6 py-4 transition-colors hover:bg-base-200/40"
                        >
                          <div class="flex flex-col gap-1">
                            <button
                              type="button"
                              phx-click="move_up"
                              phx-value-question_id={sqs.survey_question_id}
                              class={["btn btn-ghost btn-xs btn-square", index == 0 && "invisible"]}
                              title="Move up"
                              aria-label="Move up"
                            >
                              <.icon name="hero-chevron-up" class="size-4" />
                            </button>
                            <button
                              type="button"
                              phx-click="move_down"
                              phx-value-question_id={sqs.survey_question_id}
                              class={[
                                "btn btn-ghost btn-xs btn-square",
                                index == length(@selected_survey.survey_question_surveys) - 1 &&
                                  "invisible"
                              ]}
                              title="Move down"
                              aria-label="Move down"
                            >
                              <.icon name="hero-chevron-down" class="size-4" />
                            </button>
                          </div>

                          <div class="min-w-0 flex-1">
                            <%= if question = sqs.survey_question do %>
                              <p :if={question.trait} class="text-xs text-base-content/50">
                                {question.trait.trait_name}
                              </p>
                              <p class="mt-0.5 text-sm font-medium">{question.text}</p>

                              <%= if question.trait && question.trait.child_traits != [] do %>
                                <% is_expanded =
                                  MapSet.member?(@expanded_questions, sqs.survey_question_id) %>
                                <button
                                  type="button"
                                  phx-click="toggle_question_answers"
                                  phx-value-question_id={sqs.survey_question_id}
                                  class="btn btn-ghost btn-xs mt-2 -ml-2"
                                  aria-expanded={to_string(is_expanded)}
                                >
                                  <.icon
                                    name={
                                      if is_expanded, do: "hero-chevron-up", else: "hero-chevron-down"
                                    }
                                    class="size-3"
                                  />
                                  {if is_expanded, do: "Hide", else: "Show"} answers ({length(
                                    question.trait.child_traits
                                  )})
                                </button>

                                <ul :if={is_expanded} class="mt-2 space-y-1.5">
                                  <li
                                    :for={child <- question.trait.child_traits}
                                    class="flex items-start gap-2 text-sm"
                                  >
                                    <.chip>{child.display_order}</.chip>
                                    <div class="min-w-0 flex-1">
                                      <span class="font-medium">{child.trait_name}</span>
                                      <span
                                        :if={child.survey_answer}
                                        class="ml-1 text-base-content/60"
                                      >
                                        - {child.survey_answer.text}
                                      </span>
                                    </div>
                                  </li>
                                </ul>
                              <% end %>
                            <% else %>
                              <p class="text-sm text-error">
                                Question {sqs.survey_question_id} is missing from the catalog
                              </p>
                            <% end %>
                          </div>

                          <.icon_button
                            icon="hero-x-mark"
                            label="Remove from survey"
                            tone="error"
                            phx-click="remove_question"
                            phx-value-question_id={sqs.survey_question_id}
                            data-confirm="Remove this question from the survey?"
                          />
                        </li>
                      </ul>
                    </.panel>
                  <% else %>
                    <.panel>
                      <.empty_state icon="hero-clipboard-document-list" title="No survey selected">
                        Select a survey to view its questions.
                      </.empty_state>
                    </.panel>
                  <% end %>
                </div>

                <div class="min-w-0 lg:col-span-3">
                  <%= case @editor_mode do %>
                    <% :new_survey -> %>
                      <.survey_form
                        form={@form}
                        survey_categories={@survey_categories}
                        mode="new"
                        on_save="save_survey"
                        on_cancel="cancel_edit"
                      />
                    <% :edit_survey -> %>
                      <.survey_form
                        form={@form}
                        survey_categories={@survey_categories}
                        survey={@editing_survey}
                        mode="edit"
                        on_save="save_survey"
                        on_cancel="cancel_edit"
                        on_delete="delete_survey"
                      />
                    <% nil -> %>
                      <%= if @selected_survey do %>
                        <.panel
                          flush
                          title="Add questions"
                          description="Questions not yet in this survey."
                        >
                          <div class="border-b border-base-300 px-4 py-3">
                            <.search_field
                              value={@available_search}
                              placeholder="Search questions"
                              on_change="search_available"
                              on_clear="clear_available_search"
                              name="search"
                              class="w-full"
                            />
                          </div>

                          <div class="max-h-[500px] overflow-y-auto py-2">
                            <p
                              :if={@available_questions == []}
                              class="px-6 py-4 text-center text-sm text-base-content/60"
                            >
                              No available questions
                            </p>
                            <div
                              :for={
                                traits <-
                                  @available_questions
                                  |> Enum.reject(&is_nil(&1.trait_category))
                                  |> Enum.chunk_by(& &1.trait_category_id)
                              }
                              class="mb-2"
                            >
                              <p class="px-4 pt-2 pb-1 text-xs font-medium text-base-content/50">
                                {hd(traits).trait_category.name}
                              </p>
                              <div
                                :for={trait <- traits}
                                class="flex items-start gap-2 px-4 py-2 transition-colors hover:bg-base-200/40"
                              >
                                <.icon_button
                                  icon="hero-arrow-left"
                                  label="Add to survey"
                                  phx-click="add_question"
                                  phx-value-question_id={trait.survey_question.id}
                                />
                                <div class="min-w-0 flex-1">
                                  <p class="text-xs font-medium">{trait.trait_name}</p>
                                  <p class="mt-0.5 text-xs text-base-content/60">
                                    {trait.survey_question.text}
                                  </p>
                                </div>
                              </div>
                            </div>
                          </div>
                        </.panel>
                      <% else %>
                        <.panel>
                          <.empty_state icon="hero-plus-circle" title="Add questions">
                            Select a survey to add questions to it.
                          </.empty_state>
                        </.panel>
                      <% end %>
                  <% end %>
                </div>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp survey_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@on_save}>
      <.panel
        title={if @mode == "new", do: "New survey", else: "Edit survey"}
        description={
          if @mode == "new",
            do: "Create a survey, then add questions.",
            else: "Rename or recategorize."
        }
      >
        <.input field={@form[:name]} type="text" label="Survey name" required />

        <.input
          field={@form[:survey_category_id]}
          type="select"
          label="Survey category"
          prompt="Select category..."
          options={Enum.map(@survey_categories, &{&1.survey_category_name, &1.id})}
          required
        />

        <.input
          :if={@mode == "edit"}
          field={@form[:display_order]}
          type="number"
          label="Display order"
          required
        />

        <:footer>
          <button
            :if={@mode == "edit" && assigns[:on_delete]}
            type="button"
            phx-click={@on_delete}
            data-confirm="Delete this survey? This cannot be undone."
            class="btn btn-ghost text-error mr-auto"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary">
            {if @mode == "new", do: "Create survey", else: "Update survey"}
          </.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  defp category_name(%{survey_category: %{survey_category_name: name}}), do: name
  defp category_name(_survey), do: "Uncategorized"
end
