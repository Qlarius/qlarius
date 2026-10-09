defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
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
        title="Builder"
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
            show_skip_conflict={@show_skip_conflict}
            show_modal_skip={@show_modal_skip}
            zip_lookup_input={@zip_lookup_input || ""}
            zip_lookup_trait={@zip_lookup_trait}
            zip_lookup_valid={@zip_lookup_valid || false}
            current_values={@trait_in_edit_values}
            zip_lookup_error={@zip_lookup_error}
            dual_pane={true}
            show_expanded_tags={@show_expanded_tags}
            is_pwa={@is_pwa}
          />
        </:modals>

        <:slide_over_content>
          <%!-- Same thin line and check as the index row for this survey --%>
          <div :if={@survey_in_edit} class="survey-progress">
            <% total = length(@survey_in_edit.parent_traits)

            answered =
              Enum.count(@survey_in_edit.parent_traits, fn {_id, _name, _order, tags} ->
                tags != []
              end) %>
            <%= if total > 0 and answered == total do %>
              <p class="survey-progress__label">
                <.icon name="hero-check-circle-solid" class="h-5 w-5 text-success" /> All answered
              </p>
            <% else %>
              <p class="survey-progress__label">{answered} of {total} answered</p>
              <span class="progress-line" aria-hidden="true">
                <span class="progress-line__fill" style={"width: #{survey_percent(answered, total)}%"}>
                </span>
              </span>
            <% end %>
            <p class="survey-progress__intro">Tap a tag to answer or change it.</p>
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
            show_add_tags={false}
            show_search={false}
          />
        </:floating_actions>

        <Layouts.mobile_page_intro>
          Tap a topic to add or update its tags.
        </Layouts.mobile_page_intro>

        <.async_result :let={index} assign={@index}>
          <:loading>
            <.builder_index_skeleton />
          </:loading>
          <:failed>
            <p class="mobile-page-intro text-center py-8">
              Couldn't load your topics. Try refreshing.
            </p>
          </:failed>

          <%!-- Index: a glance at every topic. Category label above one card of survey rows,
             as on MeFile; a thin line shows progress and a check marks a finished survey. --%>
          <div class="builder-index pt-2">
            <%!-- Qai suggestions: topics an assistant asked about that are empty or out of
                 date, grouped by their (active) survey; orphaned traits never show. The
                 index's first card (label, card, rows), with a Qai rail. --%>
            <section
              :if={index.suggested_surveys != []}
              class="mefile-category qai-suggestions"
            >
              <div class="mefile-category__head">
                <h2 class="flex items-center gap-2">
                  Suggested by
                  <img
                    src="/images/qai_logo_color_horiz.svg"
                    alt="Qai"
                    class="h-5 w-auto shrink-0"
                  />
                </h2>
                <span class="tabular-amount">{length(index.suggested_surveys)}</span>
              </div>
              <.surface_panel padding={false} class="qai-card">
                <p class="qai-suggestions__intro">
                  From your recent chats. Answer or dismiss; nothing is added without you.
                </p>
                <ul class="builder-list">
                  <li :for={entry <- index.suggested_surveys} class="qai-suggestion">
                    <button
                      type="button"
                      phx-click="open_edit"
                      phx-value-id={entry.survey.id}
                      class="builder-row"
                    >
                      <span class="builder-row__main">
                        <span class="builder-row__name">
                          {entry.survey.name}
                          <span :if={entry.update?} class="qai-suggestion__badge">Review</span>
                        </span>
                        <span class="qai-suggestion__meta">
                          {suggestion_byline(entry)} {entry.latest.grant.mecp_client.name} · {Calendar.strftime(
                            entry.latest.inserted_at,
                            "%b %-d"
                          )}
                        </span>
                      </span>
                      <span class="builder-row__count">{entry.answered}/{entry.total}</span>
                      <.icon name="hero-chevron-right" class="builder-row__chevron h-5 w-5" />
                    </button>
                    <div class="qai-suggestion__foot">
                      <div class="min-w-0 flex-1">
                        <p :if={entry.latest.reason} class="qai-suggestion__reason">
                          "{entry.latest.reason}"
                        </p>
                        <p :if={entry.latest.proposed_values != []} class="qai-suggestion__said">
                          Mentioned in chat: {Enum.join(entry.latest.proposed_values, ", ")}
                        </p>
                      </div>
                      <button
                        type="button"
                        class="qai-suggestion__dismiss"
                        phx-click="dismiss_suggestion_group"
                        phx-value-ids={Enum.map_join(entry.suggestions, ",", & &1.id)}
                      >
                        Dismiss
                      </button>
                    </div>
                  </li>
                </ul>
              </.surface_panel>
            </section>

            <section :for={category <- visible_categories(index.categories)} class="mefile-category">
              <% {answered_total, question_total, _percent} =
                Map.get(category, :category_stats, {0, 0, 0}) %>
              <div class="mefile-category__head">
                <h2>{category.survey_category_name}</h2>
                <%!-- One survey: its row already carries the count --%>
                <span :if={length(category.surveys) > 1} class="tabular-amount">
                  {answered_total}/{question_total}
                </span>
              </div>
              <.surface_panel padding={false} class="youdata-card">
                <ul class="builder-list">
                  <li :for={survey <- category.surveys}>
                    <% {answered, total} = survey.survey_stats || {0, 0} %>
                    <button
                      type="button"
                      phx-click="open_edit"
                      phx-value-id={survey.id}
                      class="builder-row"
                    >
                      <span class="builder-row__main">
                        <span class="builder-row__name">
                          {survey_row_name(survey, category, total)}
                        </span>
                        <span :if={answered < total} class="progress-line" aria-hidden="true">
                          <span
                            class="progress-line__fill"
                            style={"width: #{survey_percent(answered, total)}%"}
                          >
                          </span>
                        </span>
                      </span>
                      <%= if answered < total do %>
                        <span class="builder-row__count">{answered}/{total}</span>
                      <% else %>
                        <.icon name="hero-check-circle-solid" class="builder-row__done h-5 w-5" />
                        <span class="sr-only">Complete</span>
                      <% end %>
                      <.icon name="hero-chevron-right" class="builder-row__chevron h-5 w-5" />
                    </button>
                  </li>
                </ul>
              </.surface_panel>
            </section>
          </div>
        </.async_result>
      </Layouts.mobile>
    </div>
    """
  end

  # The index (categories with their counts, and Qai's suggestions) loads with
  # `assign_async/3`, so the dead render and the wait for the socket show the
  # skeleton from `<.async_result>`'s :loading slot, as on Arqade and Stash.
  def mount(_params, session, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    socket =
      socket
      |> assign(:current_path, "/me_file_builder")
      |> assign_async(:index, fn -> {:ok, %{index: load_index(me_file_id)}} end)
      |> assign(:editing, false)
      |> assign(:active_survey_id, nil)
      |> assign(:survey_in_edit, nil)
      |> assign(:trait_in_edit, nil)
      |> assign(:trait_in_edit_values, [])
      |> assign(:selected_child_trait_ids, [])
      |> assign(:show_modal, false)
      |> assign(:show_delete_confirm, false)
      |> assign(:show_skip_conflict, false)
      |> assign(:show_modal_skip, false)
      |> assign(:show_expanded_tags, false)
      |> assign(:tag_search, "")
      |> assign(:show_tag_search, false)
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

  def handle_event("set_tag_display_mode", %{"mode" => mode}, socket)
      when mode in ~w(tag list) do
    me_file = socket.assigns.current_scope.user.me_file

    case MeFiles.update_tag_display_mode(me_file, mode) do
      {:ok, updated_me_file} ->
        {:noreply,
         socket
         |> assign(:tag_display_mode, updated_me_file.tag_display_mode)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update display mode")}
    end
  end

  def handle_event("sync_tag_selection", params, socket) do
    case socket.assigns.trait_in_edit do
      %{input_type: type} when type in ["multi_select", "single_select"] ->
        ids = child_trait_ids_from_form_params(params)

        {:noreply,
         socket
         |> assign(:selected_child_trait_ids, ids)
         |> assign(:show_skip_conflict, false)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    {survey_id, _} = Integer.parse(to_string(id))
    {:noreply, open_survey(socket, survey_id)}
  end

  def handle_event("dismiss_suggestion_group", %{"ids" => ids}, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    suggestion_ids =
      ids
      |> String.split(",", trim: true)
      |> Enum.flat_map(fn raw ->
        case Integer.parse(raw) do
          {id, _} -> [id]
          :error -> []
        end
      end)

    Suggestions.dismiss_many(suggestion_ids, me_file_id)

    {:noreply, reload_index(socket)}
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
      |> assign(
        :trait_in_edit_values,
        parent_trait_values(
          (socket.assigns.survey_in_edit && socket.assigns.survey_in_edit.parent_traits) || [],
          trait.id
        )
      )
      |> assign(:selected_child_trait_ids, selected_ids)
      |> assign(:show_modal_skip, selected_ids == [])
      |> assign(:show_modal, true)
      |> assign(:show_delete_confirm, false)
      |> assign(:show_skip_conflict, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> push_event("scroll-tag-list-to-top", %{})

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip_code_input" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:show_delete_confirm, false)
     |> assign(:show_skip_conflict, false)}
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

    if Traits.mixed_skip_selection?(socket.assigns.trait_in_edit, child_trait_ids) do
      {:noreply, reveal_skip_conflict(socket)}
    else
      persist_builder_tags(socket, trait_id, child_trait_ids)
    end
  end

  def handle_event("skip_trait", _params, socket) do
    case modal_skip_child(socket.assigns.trait_in_edit) do
      %{id: child_id} ->
        persist_builder_tags(socket, socket.assigns.trait_in_edit.id, [child_id])

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("skip_parent_trait", %{"id" => parent_id}, socket) do
    {parent_id, _} = Integer.parse(parent_id)
    parent = Traits.get_trait!(parent_id)
    me_file_id = socket.assigns.current_scope.user.me_file.id
    existing = MeFiles.existing_tags_per_parent_trait(me_file_id, parent_id)
    skip = Traits.active_skipped_child(parent_id)

    cond do
      QlariusWeb.Components.TraitComponents.protected_trait_name?(parent.trait_name) ->
        {:noreply, socket}

      parent.input_type == "single_select_zip" ->
        {:noreply, socket}

      existing != [] ->
        {:noreply, socket}

      is_nil(skip) ->
        {:noreply, socket}

      true ->
        persist_builder_tags(socket, parent_id, [skip.id])
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
            |> reload_index()
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

  def handle_info({:clear_skip_conflict, token}, socket) do
    if socket.assigns[:skip_conflict_token] == token do
      {:noreply, assign(socket, :show_skip_conflict, false)}
    else
      {:noreply, socket}
    end
  end

  defp reveal_skip_conflict(socket) do
    token = System.unique_integer([:positive])
    Process.send_after(self(), {:clear_skip_conflict, token}, 3_000)

    socket
    |> assign(:show_skip_conflict, true)
    |> assign(:show_delete_confirm, false)
    |> assign(:skip_conflict_token, token)
  end

  defp persist_builder_tags(socket, trait_id, child_trait_ids) do
    had_suggestion =
      Suggestions.pending_for_trait?(socket.assigns.current_scope.user.me_file.id, trait_id)

    case MeFiles.create_replace_mefile_tags(
           socket.assigns.current_scope.user.me_file.id,
           trait_id,
           child_trait_ids,
           socket.assigns.current_scope.user.id
         ) do
      :ok ->
        me_file_id = socket.assigns.current_scope.user.me_file.id

        if had_suggestion do
          MeFiles.set_tags_source_context(me_file_id, trait_id, "mecp_suggestion_confirmed")
        end

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

        socket
        |> reload_index()
        |> assign(:survey_in_edit, survey_in_edit)
        |> assign(:show_modal, false)
        |> assign(:show_delete_confirm, false)
        |> assign(:show_skip_conflict, false)
        |> push_event("animate_trait", %{
          trait_id: trait_id,
          delay_ms: 250,
          value: "update_pulse"
        })
        |> then(&{:noreply, &1})
    end
  end

  defp modal_skip_child(%{child_traits: children}) when is_list(children) do
    Enum.find(children, & &1.is_skipped_tag)
  end

  defp modal_skip_child(_), do: nil

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

  # The Builder index: every category with its survey counts, and Qai's
  # suggested surveys
  defp load_index(me_file_id) do
    answered_ids = MeFiles.get_answered_survey_question_ids(me_file_id)

    %{
      categories: Surveys.list_survey_categories_with_surveys_and_stats(me_file_id, answered_ids),
      suggested_surveys: Suggestions.suggested_surveys_for_me_file(me_file_id)
    }
  end

  # After tags change or a suggestion is dismissed: refresh in place (no skeleton)
  defp reload_index(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    assign(socket, :index, AsyncResult.ok(socket.assigns.index, load_index(me_file_id)))
  end

  # First-load placeholder in the index's own layout: category label, then a
  # card of rows (name, progress line, count), with DaisyUI `.skeleton` bones.
  defp builder_index_skeleton(assigns) do
    ~H"""
    <div
      id="builder-index-skeleton"
      class="builder-index pt-2"
      aria-busy="true"
      aria-label="Loading topics"
    >
      <section :for={rows <- [3, 2, 4, 2, 3, 2]} class="mefile-category" aria-hidden="true">
        <div class="mefile-category__head">
          <div class="skeleton h-4 w-28"></div>
        </div>
        <.surface_panel padding={false} class="youdata-card">
          <ul class="builder-list">
            <li :for={_ <- 1..rows}>
              <div class="builder-row cursor-default hover:bg-transparent">
                <span class="builder-row__main">
                  <span class="skeleton h-4 w-3/5"></span>
                  <span class="skeleton h-1 w-full rounded-full"></span>
                </span>
                <span class="skeleton h-3 w-8 shrink-0"></span>
              </div>
            </li>
          </ul>
        </.surface_panel>
      </section>
    </div>
    """
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
    |> assign(:show_tag_search, false)
  end

  defp assign_tag_display_mode(socket) do
    mode =
      case socket.assigns.current_scope.user.me_file do
        %{tag_display_mode: mode} when mode in ~w(tag list) -> mode
        _ -> "list"
      end

    assign(socket, :tag_display_mode, mode)
  end

  # Update entries mean the anchor trait already has tags: the assistant heard
  # something newer in chat. Gap entries are fills for empty traits.
  defp suggestion_byline(%{update?: true}), do: "Review suggested by"
  defp suggestion_byline(%{latest: %{source: "observed"}}), do: "Asked about by"
  defp suggestion_byline(_entry), do: "Suggested by"

  # Surveys with no questions open empty, so the index leaves them (and any
  # category left with none) out.
  defp visible_categories(categories) do
    for category <- categories,
        surveys = Enum.reject(category.surveys, &(survey_question_total(&1) == 0)),
        surveys != [],
        do: %{category | surveys: surveys}
  end

  defp survey_question_total(%{survey_stats: {_answered, total}}), do: total
  defp survey_question_total(_survey), do: 0

  # A category's only survey often shares its name ("Your Home"); say what's
  # inside instead of repeating it.
  defp survey_row_name(survey, %{surveys: [_only], survey_category_name: category_name}, total) do
    if same_name?(survey.name, category_name) do
      if total == 1, do: "1 question", else: "#{total} questions"
    else
      survey.name
    end
  end

  defp survey_row_name(survey, _category, _total), do: survey.name

  defp same_name?(a, b),
    do: String.downcase(String.trim(to_string(a))) == String.downcase(String.trim(to_string(b)))

  defp survey_percent(_answered, 0), do: 0
  defp survey_percent(answered, total), do: min(round(answered / total * 100), 100)
end
