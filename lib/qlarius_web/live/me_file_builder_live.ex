defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  import QlariusWeb.MeFileHTML
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def render(assigns) do
    ~H"""
    <div id="mefilebuilder-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile
        {assigns}
        title="Tagger"
        slide_over_active={@editing}
        slide_over_title={(@survey_in_edit && @survey_in_edit.name) || "Survey"}
      >
        <:modals>
          <.tag_edit_modal
            trait_in_edit={@trait_in_edit}
            me_file_id={@current_scope.user.me_file.id}
            selected_ids={@selected_child_trait_ids || []}
            show_modal={@show_modal}
            tag_edit_mode={@tag_edit_mode || "update"}
            zip_lookup_input={@zip_lookup_input || ""}
            zip_lookup_trait={@zip_lookup_trait}
            zip_lookup_valid={@zip_lookup_valid || false}
            zip_lookup_error={@zip_lookup_error}
            dual_pane={true}
            show_expanded_tags={@show_expanded_tags}
            is_pwa={@is_pwa}
          />
        </:modals>

        <:slide_over_content>
          <div :if={@survey_in_edit} class="mb-6">
            <% total_traits = length(@survey_in_edit.parent_traits)

            completed_traits =
              Enum.count(@survey_in_edit.parent_traits, fn {_id, _name, _order, tags} ->
                tags != []
              end)

            percent_complete =
              if total_traits == 0, do: 0, else: trunc(completed_traits / total_traits * 100) %>
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
                {completed_traits}/{total_traits}
              </div>
            </div>
            <h1 class="text-base-content mt-2 text-xl">Fill/edit/delete tags below.</h1>
          </div>

          <div class="flex flex-row flex-wrap gap-4 pt-4 pb-32">
            <.trait_card
              :for={
                {parent_trait_id, parent_trait_name, parent_trait_display_order, tags_traits} <-
                  (@survey_in_edit && @survey_in_edit.parent_traits) || []
              }
              parent_trait_id={parent_trait_id}
              parent_trait_name={parent_trait_name}
              tags_traits={tags_traits}
              clickable={true}
            />
          </div>

          <div :if={!@active_survey_id} class="text-base-content/50 text-sm">
            No survey selected
          </div>
        </:slide_over_content>

        <%!-- Main content: Survey category index --%>
        <div class="mb-8 flex gap-2 justify-start items-center">
          <span class="text-xl">Select a tag bucket below and tag away.</span>
        </div>

        <div class="mt-8 grid gap-6 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
          <%= for category <- @categories do %>
            <% {answered_total, question_total, percent_complete} =
              Map.get(category, :category_stats, {0, 0, 0}) %>
            <div class="bg-base-100 overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="text-xl leading-6 text-base-content font-bold">
                    {category.survey_category_name}
                  </h3>
                  <div class={[
                    "badge badge-lg rounded-full px-3 py-3 font-bold",
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
                      class="absolute top-0 left-0 h-6 flex items-center justify-center text-sm font-bold text-white pointer-events-none"
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
                      <span class="text-xl text-base-content">{survey.name}</span>
                      <div class="flex items-center space-x-2">
                        <span class={[
                          "badge badge-lg rounded-full px-3 py-3",
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
      </Layouts.mobile>
    </div>
    """
  end

  def mount(_params, session, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

    categories_with_stats =
      Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids)

    socket =
      socket
      |> assign(:current_path, "/me_file_builder")
      |> assign(:categories, categories_with_stats)
      |> assign(:answered_survey_question_ids, answered_ids)
      |> assign(:editing, false)
      |> assign(:active_survey_id, nil)
      |> assign(:survey_in_edit, nil)
      |> assign(:trait_in_edit, nil)
      |> assign(:selected_child_trait_ids, [])
      |> assign(:show_modal, false)
      |> assign(:tag_edit_mode, "update")
      |> assign(:show_expanded_tags, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> init_pwa_assigns(session)

    {:ok, socket, temporary_assigns: [survey_to_open: nil]}
  end

  def handle_params(params, _url, socket) do
    socket =
      case Map.get(params, "survey_id") do
        nil ->
          socket

        survey_id_str ->
          case Integer.parse(survey_id_str) do
            {survey_id, _} ->
              open_survey(socket, survey_id)

            :error ->
              socket
          end
      end

    {:noreply, socket}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("toggle_tag_view", _params, socket) do
    {:noreply, assign(socket, :show_expanded_tags, !socket.assigns.show_expanded_tags)}
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    {survey_id, _} = Integer.parse(to_string(id))
    {:noreply, open_survey(socket, survey_id)}
  end

  def handle_event("close_slide_over", _params, socket) do
    {:noreply,
     socket
     |> assign(editing: false, active_survey_id: nil)
     |> assign(:survey_in_edit, nil)}
  end

  def handle_event("edit_tags", %{"id" => trait_id}, socket) do
    {trait_id, _} = Integer.parse(trait_id)
    {:ok, trait} = Traits.get_trait_with_full_survey_data!(trait_id)

    # Load existing tags for this trait
    existing_tags =
      MeFiles.existing_tags_per_parent_trait(
        socket.assigns.current_scope.user.me_file.id,
        trait_id
      )

    selected_ids = Enum.map(existing_tags, & &1.trait_id)

    socket =
      socket
      |> assign(:trait_in_edit, trait)
      |> assign(:selected_child_trait_ids, selected_ids)
      |> assign(:show_modal, true)
      |> assign(:tag_edit_mode, "update")
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> push_event("scroll-tag-list-to-top", %{})

    {:noreply, socket}
  end

  def handle_event("delete_tags", %{"id" => trait_id}, socket) do
    {trait_id, _} = Integer.parse(trait_id)
    {:ok, trait} = Traits.get_trait_with_full_survey_data!(trait_id)

    # Load existing tags for this trait
    existing_tags =
      MeFiles.existing_tags_per_parent_trait(
        socket.assigns.current_scope.user.me_file.id,
        trait_id
      )

    selected_ids = Enum.map(existing_tags, & &1.trait_id)

    socket =
      socket
      |> assign(:trait_in_edit, trait)
      |> assign(:selected_child_trait_ids, selected_ids)
      |> assign(:show_modal, true)
      |> assign(:tag_edit_mode, "delete")
      |> ZipCodeLookup.initialize_zip_lookup_assigns()

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip_code_input" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_event(
        "save_tags",
        %{
          "me_file_id" => _me_file_id,
          "trait_id" => trait_id,
          "child_trait_ids" => child_trait_ids
        },
        socket
      ) do
    {trait_id, _} = Integer.parse(trait_id)
    child_trait_ids = List.wrap(child_trait_ids)

    # to capture the tag_value snapshot for me_file_tag
    _id_to_name_map =
      case socket.assigns.trait_in_edit.child_traits do
        %Ecto.Association.NotLoaded{} ->
          %{}

        child_traits when is_list(child_traits) ->
          Enum.reduce(child_traits, %{}, fn ct, acc ->
            Map.put(acc, ct.id, (ct.survey_answer && ct.survey_answer.text) || ct.trait_name)
          end)

        _ ->
          %{}
      end

    # Update tags and refresh survey data
    case MeFiles.create_replace_mefile_tags(
           socket.assigns.current_scope.user.me_file.id,
           trait_id,
           child_trait_ids,
           socket.assigns.current_scope.user.id
         ) do
      :ok ->
        # Refresh the survey data after tag update
        me_file_id = socket.assigns.current_scope.user.me_file.id
        answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

        categories_with_stats =
          Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids)

        survey_in_edit =
          if socket.assigns.survey_in_edit do
            parent_traits_with_tags =
              Surveys.parent_traits_for_survey_with_tags(
                socket.assigns.survey_in_edit.id,
                me_file_id
              )

            Map.put(socket.assigns.survey_in_edit, :parent_traits, parent_traits_with_tags)
          else
            nil
          end

        socket =
          socket
          |> assign(:categories, categories_with_stats)
          |> assign(:answered_survey_question_ids, answered_ids)
          |> assign(:survey_in_edit, survey_in_edit)
          |> assign(:show_modal, false)
          |> push_event("animate_trait", %{
            trait_id: trait_id,
            delay_ms: 250,
            value: "update_pulse"
          })

        {:noreply, socket}
    end
  end

  def handle_event(
        "perform_delete_tags",
        %{
          "me_file_id" => _me_file_id,
          "trait_id" => trait_id,
          "child_trait_ids" => child_trait_ids
        },
        socket
      ) do
    {trait_id, _} = Integer.parse(trait_id)
    child_trait_ids = List.wrap(child_trait_ids)

    # Delete tags and refresh survey data
    case MeFiles.delete_mefile_tags(
           socket.assigns.current_scope.user.me_file.id,
           trait_id,
           child_trait_ids
         ) do
      :ok ->
        # Refresh the survey data after tag deletion
        me_file_id = socket.assigns.current_scope.user.me_file.id
        answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

        categories_with_stats =
          Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids)

        survey_in_edit =
          if socket.assigns.survey_in_edit do
            parent_traits_with_tags =
              Surveys.parent_traits_for_survey_with_tags(
                socket.assigns.survey_in_edit.id,
                me_file_id
              )

            Map.put(socket.assigns.survey_in_edit, :parent_traits, parent_traits_with_tags)
          else
            nil
          end

        socket =
          socket
          |> assign(:categories, categories_with_stats)
          |> assign(:answered_survey_question_ids, answered_ids)
          |> assign(:survey_in_edit, survey_in_edit)
          |> assign(:show_modal, false)
          |> push_event("animate_trait", %{
            trait_id: trait_id,
            delay_ms: 250,
            value: "delete_fade"
          })

        {:noreply, socket}
    end
  end

  defp open_survey(socket, survey_id) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    survey = Surveys.get_survey!(survey_id)
    parent_traits_with_tags = Surveys.parent_traits_for_survey_with_tags(survey_id, me_file_id)

    survey_in_edit = %{
      id: survey_id,
      name: survey.name,
      parent_traits: parent_traits_with_tags
    }

    socket
    |> assign(editing: true, active_survey_id: survey_id)
    |> assign(:survey_in_edit, survey_in_edit)
  end
end
