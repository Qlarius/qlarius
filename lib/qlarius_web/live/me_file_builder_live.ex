defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Qlarius.MeCP.Suggestions
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
        title="Tag Index"
        slide_over_active={@editing}
        slide_over_title={(@survey_in_edit && @survey_in_edit.name) || "Survey"}
      >
        <:modals>
          <.tag_edit_modal
            trait_in_edit={@trait_in_edit}
            me_file_id={@current_scope.user.me_file.id}
            selected_ids={@selected_child_trait_ids || []}
            show_modal={@show_modal}
            show_delete_confirm={@show_delete_confirm}
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
            <div class="relative tagger-progress">
              <progress
                class={[
                  "progress w-full h-6",
                  cond do
                    percent_complete == 0 -> "tagger-progress-zero"
                    percent_complete == 100 -> "progress-success"
                    true -> "progress-warning"
                  end
                ]}
                value={if percent_complete == 0, do: 0, else: max(22, percent_complete)}
                max="100"
              >
              </progress>
              <%= if percent_complete == 0 do %>
                <div class="tagger-progress-fill-label tagger-zero-progress-chip text-xs leading-none">
                  {completed_traits}/{total_traits}
                </div>
              <% else %>
                <div
                  class="tagger-progress-fill-label text-xs leading-none"
                  style={"width: #{max(22, percent_complete)}%"}
                >
                  {completed_traits}/{total_traits}
                </div>
              <% end %>
            </div>
            <p class="mobile-page-intro mt-2 mb-0">
              Fill the empty tags below. Update or delete existing tags.
            </p>
          </div>

          <%!-- Provenance bylines for the virtual suggestions survey: each entry
               is the assistant's words, clearly attributed, with a dismiss. --%>
          <div
            :if={@survey_in_edit && @survey_in_edit.id == :suggestions}
            class="mb-4 flex flex-col gap-2"
          >
            <div
              :for={s <- @pending_suggestions}
              class="flex items-start justify-between gap-2 text-sm bg-base-200 dark:bg-base-300/40 rounded-lg p-3"
            >
              <div class="min-w-0">
                <div class="font-medium">{s.trait.trait_name}</div>
                <div class="text-base-content/60">
                  {if s.source == "observed", do: "Asked about by", else: "Suggested by"} {s.grant.mecp_client.name} on {Calendar.strftime(
                    s.inserted_at,
                    "%b %d"
                  )}
                </div>
                <div :if={s.reason} class="text-base-content/60 italic">"{s.reason}"</div>
                <div :if={s.proposed_values != []} class="text-base-content/60">
                  Mentioned: {Enum.join(s.proposed_values, ", ")}
                </div>
              </div>
              <button
                class="btn btn-xs btn-ghost shrink-0"
                phx-click="dismiss_suggestion"
                phx-value-id={s.id}
              >
                Dismiss
              </button>
            </div>
          </div>

          <.survey_traits_display
            :if={@survey_in_edit}
            parent_traits={@survey_in_edit.parent_traits}
            tag_display_mode={@tag_display_mode}
            tag_search={@tag_search}
          />

          <div :if={!@active_survey_id} class="text-base-content/50 text-sm">
            No survey selected
          </div>
        </:slide_over_content>

        <:floating_actions>
          <.mefile_floating_toolbar
            :if={@editing}
            tag_search={@tag_search}
            tag_display_mode={@tag_display_mode}
            show_tag_search={@show_tag_search}
            show_view_menu={@show_view_menu}
            show_add_tags={false}
            show_search={false}
          />
        </:floating_actions>

        <%!-- Main content: Survey category index --%>
        <Layouts.mobile_page_intro>
          Select a category below and fill empty tags.
        </Layouts.mobile_page_intro>

        <%!-- Virtual survey: pending suggestions from connected assistants --%>
        <div :if={@pending_suggestions != []} class="mt-8">
          <.surface_panel padding={false}>
            <div
              class="p-4 cursor-pointer transition-colors hover:bg-base-200/60 rounded-2xl"
              phx-click="open_suggestions"
            >
              <div class="flex justify-between items-center">
                <div class="flex items-center gap-2">
                  <.icon name="hero-sparkles" class="w-5 h-5 text-primary" />
                  <span class="text-xl text-base-content">From Recent Chats</span>
                  <span class="badge badge-primary badge-sm">{length(@pending_suggestions)}</span>
                </div>
                <.icon name="hero-chevron-right" class="w-5 h-5 shrink-0 text-base-content/60" />
              </div>
              <p class="text-sm text-base-content/60 mt-1">
                Your AI assistants noticed these gaps. Answer or dismiss; nothing is added
                without you.
              </p>
            </div>
          </.surface_panel>
        </div>

        <div class="mt-8 grid gap-10 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
          <%= for category <- @categories do %>
            <% {answered_total, question_total, percent_complete} =
              Map.get(category, :category_stats, {0, 0, 0}) %>
            <.surface_panel padding={false}>
              <div class="flex justify-between items-center px-4 pt-4 pb-3">
                <h2 class="text-lg font-bold tracking-tight text-base-content/50">
                  {category.survey_category_name}
                </h2>
                <span class="text-sm text-base-content/50">
                  {answered_total}/{question_total}
                </span>
              </div>
              <div class="px-4 pb-4">
                <div class="tagger-progress tagger-progress-thin mb-4">
                  <progress
                    class={[
                      "progress w-full",
                      cond do
                        percent_complete == 0 -> "tagger-progress-zero"
                        percent_complete == 100 -> "progress-success"
                        true -> "progress-warning"
                      end
                    ]}
                    value={percent_complete}
                    max="100"
                  >
                  </progress>
                </div>

                <%= for survey <- category.surveys do %>
                  <% {answered_question_count, question_count} = survey.survey_stats || {0, 0} %>
                  <div
                    class="mb-3 p-3 bg-base-200 dark:bg-base-300/40 rounded-full cursor-pointer transition-colors hover:bg-base-300 dark:hover:bg-base-300/60"
                    phx-click="open_edit"
                    phx-value-id={survey.id}
                  >
                    <div class="flex justify-between items-center">
                      <span class="text-xl text-base-content">{survey.name}</span>
                      <div class="flex items-center gap-2">
                        <span class={survey_ratio_text_class(answered_question_count, question_count)}>
                          {answered_question_count}/{question_count}
                        </span>
                        <.icon
                          name="hero-chevron-right"
                          class="w-5 h-5 shrink-0 text-base-content/60"
                        />
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </.surface_panel>
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
      |> assign(:pending_suggestions, Suggestions.list_pending_for_me_file(me_file_id))
      |> assign(:answered_survey_question_ids, answered_ids)
      |> assign(:editing, false)
      |> assign(:active_survey_id, nil)
      |> assign(:survey_in_edit, nil)
      |> assign(:trait_in_edit, nil)
      |> assign(:selected_child_trait_ids, [])
      |> assign(:show_modal, false)
      |> assign(:show_delete_confirm, false)
      |> assign(:show_expanded_tags, false)
      |> assign(:tag_search, "")
      |> assign(:show_tag_search, false)
      |> assign(:show_view_menu, false)
      |> assign_tag_display_mode()
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

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_tag_view", %{"expanded" => expanded}, socket) do
    {:noreply, assign(socket, :show_expanded_tags, expanded == "true")}
  end

  def handle_event("toggle_view_menu", _params, socket) do
    show = !socket.assigns.show_view_menu

    {:noreply,
     socket
     |> assign(:show_view_menu, show)
     |> assign(:show_tag_search, false)}
  end

  def handle_event("set_tag_display_mode", %{"mode" => mode}, socket)
      when mode in ~w(tag block list) do
    me_file = socket.assigns.current_scope.user.me_file

    case MeFiles.update_tag_display_mode(me_file, mode) do
      {:ok, updated_me_file} ->
        {:noreply,
         socket
         |> assign(:tag_display_mode, updated_me_file.tag_display_mode)
         |> assign(:show_view_menu, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update display mode")}
    end
  end

  def handle_event("sync_tag_selection", params, socket) do
    case socket.assigns.trait_in_edit do
      %{input_type: type} when type in ["multi_select", "single_select"] ->
        ids = child_trait_ids_from_form_params(params)
        {:noreply, assign(socket, :selected_child_trait_ids, ids)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    {survey_id, _} = Integer.parse(to_string(id))
    {:noreply, open_survey(socket, survey_id)}
  end

  def handle_event("open_suggestions", _params, socket) do
    {:noreply, open_suggestions_survey(socket)}
  end

  def handle_event("dismiss_suggestion", %{"id" => id}, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    {suggestion_id, _} = Integer.parse(to_string(id))

    Suggestions.dismiss(suggestion_id, me_file_id)
    socket = refresh_suggestions(socket)

    # Close the slide-over when the last suggestion is handled.
    if socket.assigns.pending_suggestions == [] and
         socket.assigns.active_survey_id == :suggestions do
      {:noreply,
       socket
       |> assign(editing: false, active_survey_id: nil)
       |> assign(:survey_in_edit, nil)}
    else
      {:noreply, socket}
    end
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
      |> assign(:show_delete_confirm, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> push_event("scroll-tag-list-to-top", %{})

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip_code_input" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:show_modal, false) |> assign(:show_delete_confirm, false)}
  end

  def handle_event("request_delete_confirm", _params, socket) do
    if (socket.assigns.selected_child_trait_ids || []) == [] do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :show_delete_confirm, !socket.assigns.show_delete_confirm)}
    end
  end

  def handle_event("cancel_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
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

        # Answered through the virtual suggestions survey: stamp the capture
        # surface (the write itself already resolved the suggestion).
        if socket.assigns.active_survey_id == :suggestions do
          MeFiles.set_tags_source_context(me_file_id, trait_id, "mecp_suggestion_confirmed")
        end

        answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

        categories_with_stats =
          Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids)

        survey_in_edit =
          case socket.assigns.survey_in_edit do
            nil ->
              nil

            %{id: :suggestions} = survey ->
              Map.put(
                survey,
                :parent_traits,
                Suggestions.parent_traits_for_suggestions(me_file_id)
              )

            survey ->
              parent_traits_with_tags =
                Surveys.parent_traits_for_survey_with_tags(survey.id, me_file_id)

              Map.put(survey, :parent_traits, parent_traits_with_tags)
          end

        socket =
          socket
          |> assign(:categories, categories_with_stats)
          |> assign(:answered_survey_question_ids, answered_ids)
          |> assign(:survey_in_edit, survey_in_edit)
          |> assign(:pending_suggestions, Suggestions.list_pending_for_me_file(me_file_id))
          |> assign(:show_modal, false)
          |> assign(:show_delete_confirm, false)
          |> push_event("animate_trait", %{
            trait_id: trait_id,
            delay_ms: 250,
            value: "update_pulse"
          })

        {:noreply, socket}
    end
  end

  def handle_event("confirm_delete_tags", _params, socket) do
    trait_id = socket.assigns.trait_in_edit.id
    child_trait_ids = socket.assigns.selected_child_trait_ids || []

    if child_trait_ids == [] do
      {:noreply, socket}
    else
      case MeFiles.delete_mefile_tags(
             socket.assigns.current_scope.user.me_file.id,
             trait_id,
             child_trait_ids
           ) do
        :ok ->
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
            |> assign(:show_delete_confirm, false)
            |> push_event("animate_trait", %{
              trait_id: trait_id,
              delay_ms: 250,
              value: "delete_fade"
            })

          {:noreply, socket}
      end
    end
  end

  defp child_trait_ids_from_form_params(params) do
    params
    |> Map.get("child_trait_ids")
    |> List.wrap()
    |> Enum.flat_map(fn raw ->
      case Integer.parse(to_string(raw)) do
        {id, _} -> [id]
        :error -> []
      end
    end)
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
    |> assign(:show_view_menu, false)
    |> assign(:show_tag_search, false)
  end

  # The virtual survey: pending assistant suggestions rendered through the
  # same components as real surveys (see MeCP.Suggestions).
  defp open_suggestions_survey(socket) do
    socket = refresh_suggestions(socket)

    socket
    |> assign(editing: true, active_survey_id: :suggestions)
    |> assign(:show_view_menu, false)
    |> assign(:show_tag_search, false)
  end

  defp refresh_suggestions(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    pending = Suggestions.list_pending_for_me_file(me_file_id)

    survey_in_edit =
      if socket.assigns[:active_survey_id] == :suggestions or
           match?(%{id: :suggestions}, socket.assigns[:survey_in_edit]) or
           socket.assigns[:survey_in_edit] == nil do
        %{
          id: :suggestions,
          name: "From Recent Chats",
          parent_traits: Suggestions.parent_traits_for_suggestions(me_file_id)
        }
      else
        socket.assigns.survey_in_edit
      end

    socket
    |> assign(:pending_suggestions, pending)
    |> assign(:survey_in_edit, survey_in_edit)
  end

  defp assign_tag_display_mode(socket) do
    mode =
      case socket.assigns.current_scope.user.me_file do
        %{tag_display_mode: mode} when mode in ~w(tag block list) -> mode
        _ -> "tag"
      end

    assign(socket, :tag_display_mode, mode)
  end

  defp survey_ratio_text_class(answered, total) do
    base = "text-sm font-medium shrink-0"

    color =
      cond do
        answered == 0 -> "text-base-content/50"
        answered == total -> "text-success"
        true -> "text-warning"
      end

    "#{base} #{color}"
  end
end
