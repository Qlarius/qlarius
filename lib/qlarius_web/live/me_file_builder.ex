defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.MeFiles

  def render(assigns) do
    ~H"""
    <Layouts.mobile {assigns} title="MeFile Builder">
      <h1>Tag yourself to build up your MeFile.</h1>

      <style phx-no-curly-interpolation>
        .survey-panels { position: relative; width: 100%; overflow: hidden; }
        .survey-panels .track { display: flex; width: 200%; transform: translateX(0); transition: transform 300ms ease-in-out; }
        .survey-panels.editing .track { transform: translateX(-50%); }
        .survey-panels .survey-panel { width: 50%; flex: 0 0 50%; }
      </style>

      <div class={[
        "survey-panels",
        @editing && "editing"
      ]}>
        <div class="track">
          <div class="survey-panel survey-index-panel">
            <div class="mt-8 grid gap-6 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
              <%= for category <- @categories do %>
                <% {answered_total, question_total, percent_complete} =
                  Map.get(category, :category_stats, {0, 0, 0}) %>
                <div class="bg-base-100 overflow-hidden shadow rounded-lg">
                  <div class="px-4 py-5 sm:p-6">
                    <div class="flex items-center justify-between mb-2">
                      <h3 class="text-lg font-medium leading-6 text-base-content">
                        {category.survey_category_name}
                      </h3>
                      <div class={[
                        "badge text-sm rounded-full px-2 py-1 font-bold",
                        cond do
                          percent_complete == 0 -> "badge-error"
                          percent_complete == 100 -> "badge-success"
                          true -> "badge-warning"
                        end
                      ]}>
                        {answered_total}/{question_total}
                      </div>
                    </div>
                    <div class="mb-5">
                      <div class="relative">
                        <progress
                          class={[
                            "progress w-full h-6",
                            cond do
                              percent_complete == 0 -> "progress-error"
                              percent_complete == 100 -> "progress-success"
                              true -> "progress-warning"
                            end
                          ]}
                          value={max(10, percent_complete)}
                          max="100"
                        >
                        </progress>
                        <div
                          class="absolute top-0 left-0 h-6 flex items-center justify-center text-xs font-bold text-white pointer-events-none"
                          style={"width: #{max(10, percent_complete)}%"}
                        >
                          {percent_complete}%
                        </div>
                      </div>
                    </div>

                    <%= for survey <- category.surveys do %>
                      <% {answered_question_count, question_count} = survey.survey_stats || {0, 0} %>
                      <div
                        class="mb-3 p-3 bg-base-200 rounded-lg cursor-pointer"
                        phx-click="open_edit"
                        phx-value-id={survey.id}
                      >
                        <div class="flex justify-between items-center">
                          <span class="text-sm font-medium text-base-content">{survey.name}</span>
                          <div class="flex items-center space-x-2">
                            <span class={[
                              "badge badge-sm rounded-full text-xs px-1 py-1",
                              cond do
                                answered_question_count == 0 -> "badge-error"
                                answered_question_count == question_count -> "badge-success"
                                true -> "badge-warning"
                              end
                            ]}>
                              {answered_question_count}/{question_count}
                            </span>
                            <.icon name="hero-chevron-right" class="w-5 h-5 text-base-content/60" />
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <div class="survey-panel survey-edit-panel">
            <div class="p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-medium text-base-content">Edit Survey</h3>
                <button type="button" phx-click="close_edit" class="btn btn-sm btn-primary">
                  Done
                </button>
              </div>
              <div :if={@active_survey_id} class="text-base-content/70 text-sm">
                Survey ID: {@active_survey_id}
              </div>
              <div :if={!@active_survey_id} class="text-base-content/50 text-sm">
                No survey selected
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.mobile>
    """
  end

  def mount(_params, _session, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

    categories_with_stats =
      Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids)

    socket =
      socket
      |> assign(:categories, categories_with_stats)
      |> assign(:answered_survey_question_ids, answered_ids)
      |> assign(:editing, false)
      |> assign(:active_survey_id, nil)

    {:ok, socket}
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    {survey_id, _} = Integer.parse(to_string(id))
    {:noreply, assign(socket, editing: true, active_survey_id: survey_id)}
  end

  def handle_event("close_edit", _params, socket) do
    {:noreply, assign(socket, editing: false, active_survey_id: nil)}
  end
end
