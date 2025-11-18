defmodule QlariusWeb.Admin.SurveyManagerLive do
  use QlariusWeb, :live_view

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
      <div class="max-w-[1600px] mx-auto p-6">
        <h1 class="text-3xl font-bold mb-6">Survey Manager</h1>

        <div class="grid grid-cols-12 gap-6">
          <%!-- Column 1: Survey Selector --%>
          <div class="col-span-3">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-4">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="card-title text-lg">Surveys</h2>
                  <button
                    phx-click="new_survey"
                    class="btn btn-circle btn-sm btn-primary"
                    title="New Survey"
                  >
                    <.icon name="hero-plus" class="w-5 h-5" />
                  </button>
                </div>

                <div class="form-control mb-4">
                  <form phx-change="search" class="relative">
                    <input
                      type="text"
                      placeholder="Search..."
                      class="input input-bordered input-sm w-full pr-8"
                      value={@search_query}
                      phx-debounce="300"
                      name="search"
                    />
                    <button
                      type="button"
                      phx-click="clear_search"
                      class={[
                        "absolute right-2 top-1/2 -translate-y-1/2",
                        @search_query == "" && "invisible pointer-events-none"
                      ]}
                    >
                      <.icon name="hero-x-circle" class="w-4 h-4 opacity-50 hover:opacity-100" />
                    </button>
                  </form>
                </div>

                <div class="overflow-y-auto max-h-[600px] space-y-1">
                  <%= if @surveys == [] do %>
                    <div class="text-center text-sm text-base-content/50 py-4">
                      No surveys found
                    </div>
                  <% else %>
                    <%= for surveys <- Enum.chunk_by(@surveys, & &1.survey_category_id) do %>
                      <div class="mb-4">
                        <div class="text-xs font-bold text-base-content/60 px-2 py-1 uppercase">
                          {hd(surveys).survey_category.survey_category_name}
                        </div>
                        <%= for survey <- surveys do %>
                          <div
                            phx-click="select_survey"
                            phx-value-id={survey.id}
                            class={[
                              "flex items-center justify-between p-2 rounded hover:bg-base-200 cursor-pointer",
                              @selected_survey && @selected_survey.id == survey.id && "bg-primary/10"
                            ]}
                          >
                            <span class="text-sm truncate flex-1">{survey.name}</span>
                            <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Column 2: Survey Details --%>
          <div class="col-span-6">
            <%= if @selected_survey do %>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body p-4">
                  <div class="flex items-center justify-between mb-4">
                    <div>
                      <h2 class="text-2xl font-bold">{@selected_survey.name}</h2>
                      <p class="text-sm text-base-content/70">
                        Category: {@selected_survey.survey_category.survey_category_name}
                      </p>
                      <p class="text-sm text-base-content/70">
                        Questions: {length(@selected_survey.survey_question_surveys)}
                      </p>
                    </div>
                    <button
                      phx-click="edit_survey"
                      class="btn btn-sm btn-ghost"
                      title="Edit Survey"
                    >
                      <.icon name="hero-pencil-square" class="w-4 h-4" />
                    </button>
                  </div>

                  <div class="divider"></div>

                  <%= if @selected_survey.survey_question_surveys == [] do %>
                    <div class="text-center py-8 text-base-content/50">
                      No questions in this survey yet
                    </div>
                  <% else %>
                    <div class="space-y-0">
                      <%= for {sqs, index} <- Enum.with_index(@selected_survey.survey_question_surveys) do %>
                        <div class="flex items-start gap-3 py-4 px-2 border-b border-base-content/10 hover:bg-base-200">
                          <div class="flex flex-col gap-1">
                            <button
                              phx-click="move_up"
                              phx-value-question_id={sqs.survey_question_id}
                              class={[
                                "btn btn-xs btn-circle btn-ghost",
                                index == 0 && "invisible"
                              ]}
                              title="Move up"
                            >
                              <.icon name="hero-chevron-up" class="w-4 h-4" />
                            </button>
                            <button
                              phx-click="move_down"
                              phx-value-question_id={sqs.survey_question_id}
                              class={[
                                "btn btn-xs btn-circle btn-ghost",
                                index == length(@selected_survey.survey_question_surveys) - 1 &&
                                  "invisible"
                              ]}
                              title="Move down"
                            >
                              <.icon name="hero-chevron-down" class="w-4 h-4" />
                            </button>
                          </div>

                          <div class="flex-1">
                            <%= if sqs.survey_question.trait do %>
                              <div class="text-sm font-semibold text-base-content/70">
                                {sqs.survey_question.trait.trait_name}
                              </div>
                            <% end %>
                            <div class="text-base mt-1">
                              {sqs.survey_question.text}
                            </div>

                            <%= if sqs.survey_question.trait && sqs.survey_question.trait.child_traits != [] do %>
                              <% is_expanded =
                                MapSet.member?(@expanded_questions, sqs.survey_question_id) %>
                              <button
                                phx-click="toggle_question_answers"
                                phx-value-question_id={sqs.survey_question_id}
                                class="btn btn-xs btn-ghost mt-2"
                              >
                                <.icon
                                  name={
                                    if is_expanded, do: "hero-chevron-up", else: "hero-chevron-down"
                                  }
                                  class="w-3 h-3"
                                />
                                {if is_expanded, do: "Hide", else: "Show"} Answers
                                ({length(sqs.survey_question.trait.child_traits)})
                              </button>

                              <%= if is_expanded do %>
                                <div class="mt-3 ml-4 space-y-1">
                                  <%= for child <- sqs.survey_question.trait.child_traits do %>
                                    <div class="flex items-start gap-2 text-sm">
                                      <div class="badge badge-sm badge-outline">
                                        {child.display_order}
                                      </div>
                                      <div class="flex-1">
                                        <span class="font-medium">{child.trait_name}</span>
                                        <%= if child.survey_answer do %>
                                          <span class="text-base-content/60 ml-2">
                                            - {child.survey_answer.text}
                                          </span>
                                        <% end %>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>
                              <% end %>
                            <% end %>
                          </div>

                          <button
                            phx-click="remove_question"
                            phx-value-question_id={sqs.survey_question_id}
                            data-confirm="Remove this question from the survey?"
                            class="btn btn-xs btn-circle btn-ghost text-error"
                            title="Remove from survey"
                          >
                            <.icon name="hero-x-mark" class="w-4 h-4" />
                          </button>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <p class="text-center text-base-content/50">Select a survey to view details</p>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Column 3: Editor --%>
          <div class="col-span-3">
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
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body p-4">
                      <h3 class="text-lg font-bold mb-4">Add Questions</h3>

                      <div class="form-control mb-4">
                        <form phx-change="search_available" class="relative">
                          <input
                            type="text"
                            placeholder="Search questions..."
                            class="input input-bordered input-sm w-full pr-8"
                            value={@available_search}
                            phx-debounce="300"
                            name="search"
                          />
                          <button
                            type="button"
                            phx-click="clear_available_search"
                            class={[
                              "absolute right-2 top-1/2 -translate-y-1/2",
                              @available_search == "" && "invisible pointer-events-none"
                            ]}
                          >
                            <.icon name="hero-x-circle" class="w-4 h-4 opacity-50 hover:opacity-100" />
                          </button>
                        </form>
                      </div>

                      <div class="overflow-y-auto max-h-[500px] space-y-2">
                        <%= if @available_questions == [] do %>
                          <div class="text-center text-sm text-base-content/50 py-4">
                            No available questions
                          </div>
                        <% else %>
                          <%= for traits <- @available_questions |> Enum.reject(&is_nil(&1.trait_category)) |> Enum.chunk_by(& &1.trait_category_id) do %>
                            <div>
                              <div class="text-xs font-bold text-base-content/60 px-2 py-1 uppercase">
                                {hd(traits).trait_category.name}
                              </div>
                              <%= for trait <- traits do %>
                                <div class="flex items-start gap-2 p-2 rounded hover:bg-base-200">
                                  <button
                                    phx-click="add_question"
                                    phx-value-question_id={trait.survey_question.id}
                                    class="btn btn-xs btn-circle btn-primary"
                                    title="Add to survey"
                                  >
                                    <.icon name="hero-arrow-left" class="w-3 h-3" />
                                  </button>
                                  <div class="flex-1">
                                    <div class="text-xs font-semibold text-base-content/70">
                                      {trait.trait_name}
                                    </div>
                                    <div class="text-xs mt-1 text-base-content/60">
                                      {trait.survey_question.text}
                                    </div>
                                  </div>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body">
                      <p class="text-center text-base-content/50">Select a survey to add questions</p>
                    </div>
                  </div>
                <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp survey_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-4">
        <h2 class="card-title text-xl mb-4">
          <.icon
            name={if @mode == "new", do: "hero-plus-circle", else: "hero-pencil-square"}
            class="w-5 h-5"
          />
          {if @mode == "new", do: "New Survey", else: "Edit Survey"}
        </h2>

        <.form for={@form} phx-submit={@on_save}>
          <div class="space-y-4">
            <.input
              field={@form[:name]}
              type="text"
              label="Survey name"
              class="input input-bordered w-full"
              required
            />

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Survey category</span>
              </label>
              <select name="survey[survey_category_id]" class="select select-bordered w-full" required>
                <option value="">Select category...</option>
                <%= for category <- @survey_categories do %>
                  <option
                    value={category.id}
                    selected={
                      Phoenix.HTML.Form.input_value(@form, :survey_category_id) == category.id
                    }
                  >
                    {category.survey_category_name}
                  </option>
                <% end %>
              </select>
            </div>

            <%= if @mode == "edit" do %>
              <.input
                field={@form[:display_order]}
                type="number"
                label="Display order"
                class="input input-bordered w-full"
                required
              />
            <% end %>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary flex-1">
                {if @mode == "new", do: "Create Survey", else: "Update Survey"}
              </button>
              <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
                Cancel
              </button>
            </div>

            <%= if @mode == "edit" && assigns[:on_delete] do %>
              <div class="divider"></div>
              <button
                type="button"
                phx-click={@on_delete}
                data-confirm="Delete this survey? This cannot be undone."
                class="btn btn-error w-full"
              >
                Delete Survey
              </button>
            <% end %>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
