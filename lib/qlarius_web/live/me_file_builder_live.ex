defmodule QlariusWeb.MeFileBuilderLive do
  use QlariusWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias Qlarius.MeCP.Suggestions
  alias Qlarius.YouData.Surveys
  alias Qlarius.YouData.MeFiles
  alias Qlarius.YouData.TraitSearch
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  import QlariusWeb.MeFileHTML
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @trait_search_max_length 80
  @trait_result_limit 15

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
            highlight_ids={@highlight_child_ids}
            chat_note={@chat_note}
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
          <%!-- Index: the same floating search as MeFile. A survey's own toolbar
               (its two views) takes over while one is open. --%>
          <.mefile_floating_toolbar
            :if={!@editing}
            tag_search={@trait_search}
            tag_display_mode={@tag_display_mode}
            show_tag_search={@show_trait_search}
            show_add_tags={false}
            show_view_modes={@show_trait_search or searchable?(@trait_search)}
            search_toggle="toggle_trait_search"
            search_change="trait_search"
            search_clear="clear_trait_search"
            search_hide="hide_trait_search"
            search_name="q"
            search_form_id="builder-trait-search"
            search_input_id="builder-trait-search-input"
            search_label="Search topics and tags"
            search_placeholder="Topics and tags"
            search_debounce="200"
          />
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

        <%!-- Hidden while a survey is open: that survey already owns the
             trait-card ids the strobe looks up. --%>
        <.async_result
          :let={results}
          :if={searchable?(@trait_search) and not @editing}
          assign={@trait_results}
        >
          <:loading>
            <.trait_search_skeleton tag_display_mode={@tag_display_mode} />
          </:loading>
          <:failed>
            <p class="mobile-page-intro text-center py-8">
              Couldn't search topics. Try again.
            </p>
          </:failed>
          <%!-- A later keystroke keeps these rows (assign_async does) and fades
               them until the new ones arrive. The skeleton is only the first
               search, while there is nothing to keep. --%>
          <div class={@trait_results.loading && "builder-results--pending"}>
            <.trait_search_results
              results={results}
              trait_search={@trait_search}
              tag_display_mode={@tag_display_mode}
            />
          </div>
        </.async_result>

        <.async_result :let={index} :if={not searchable?(@trait_search)} assign={@index}>
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
            <%!-- Qai suggestions: one row per trait an assistant asked about or proposed,
                 naming the values from chat that aren't on file yet. A tap opens that
                 trait's editor with them ticked; orphaned traits never show. The
                 index's first card (label, card, rows), with a Qai rail. --%>
            <section
              :if={index.suggested_traits != []}
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
                <span class="tabular-amount">{length(index.suggested_traits)}</span>
              </div>
              <.surface_panel padding={false} class="qai-card">
                <p class="qai-suggestions__intro">
                  From your recent chats. Answer or dismiss; nothing is added without you.
                </p>
                <ul class="builder-list">
                  <li
                    :for={entry <- index.suggested_traits}
                    id={"qai-suggestion-#{entry.suggestion.id}"}
                    class="qai-suggestion"
                  >
                    <button
                      type="button"
                      phx-click="open_suggestion"
                      phx-value-id={entry.suggestion.id}
                      class="builder-row"
                    >
                      <span class="builder-row__main">
                        <span class="builder-row__name">
                          {entry.trait.trait_name}
                          <span :if={entry.update?} class="qai-suggestion__badge">Review</span>
                        </span>
                        <span :if={entry.new_values != []} class="qai-suggestion__add">
                          Add {join_names(entry.new_values)}
                        </span>
                        <span class="qai-suggestion__meta">
                          In {entry.survey.name} · {suggestion_byline(entry)} {entry.suggestion.grant.mecp_client.name} · {Calendar.strftime(
                            entry.suggestion.inserted_at,
                            "%b %-d"
                          )}
                        </span>
                      </span>
                      <.icon name="hero-chevron-right" class="builder-row__chevron h-5 w-5" />
                    </button>
                    <div class="qai-suggestion__foot">
                      <div class="min-w-0 flex-1">
                        <p :if={entry.suggestion.reason} class="qai-suggestion__reason">
                          "{entry.suggestion.reason}"
                        </p>
                        <p :if={entry.unmatched_values != []} class="qai-suggestion__said">
                          Also mentioned: {Enum.join(entry.unmatched_values, ", ")}
                        </p>
                      </div>
                      <.link
                        :if={related_query(entry)}
                        patch={~p"/me_file_builder?#{[q: related_query(entry)]}"}
                        class="qai-suggestion__related"
                      >
                        Related
                      </.link>
                      <button
                        type="button"
                        class="qai-suggestion__dismiss"
                        phx-click="dismiss_suggestion"
                        phx-value-id={entry.suggestion.id}
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
      |> assign(:trait_search, "")
      |> assign(:show_trait_search, false)
      |> assign(:trait_results, %AsyncResult{})
      |> assign(:highlight_child_ids, [])
      |> assign(:chat_note, nil)
      |> assign_tag_display_mode()
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> init_pwa_assigns(session)

    {:ok, socket, temporary_assigns: [survey_to_open: nil]}
  end

  # ?survey_id= opens a survey, ?q= fills the search, and ?suggestion= opens
  # that suggestion's tag editor (links from Qai land here).
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> maybe_open_survey(parse_id(params["survey_id"]))
      |> maybe_search(params["q"])
      |> maybe_open_suggestion(parse_id(params["suggestion"]))

    {:noreply, socket}
  end

  defp maybe_open_survey(socket, nil), do: socket
  defp maybe_open_survey(socket, survey_id), do: open_survey(socket, survey_id)

  # Drops the query, and a ?q= link's param with it.
  defp close_trait_search(socket) do
    socket
    |> assign(:show_trait_search, false)
    |> assign_trait_search("")
    |> push_patch(to: ~p"/me_file_builder")
  end

  defp maybe_search(socket, q) when is_binary(q) and q != "" do
    socket |> assign(:show_trait_search, true) |> assign_trait_search(q)
  end

  defp maybe_search(socket, _q), do: socket

  defp maybe_open_suggestion(socket, nil), do: socket
  defp maybe_open_suggestion(socket, suggestion_id), do: open_suggestion(socket, suggestion_id)

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_id(_value), do: nil

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

  def handle_event("open_suggestion", %{"id" => id}, socket) do
    case parse_id(to_string(id)) do
      nil -> {:noreply, socket}
      suggestion_id -> {:noreply, open_suggestion(socket, suggestion_id)}
    end
  end

  def handle_event("dismiss_suggestion", %{"id" => id}, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    case parse_id(to_string(id)) do
      nil -> :ok
      suggestion_id -> Suggestions.dismiss(suggestion_id, me_file_id)
    end

    {:noreply, reload_index(socket)}
  end

  def handle_event("toggle_trait_search", _params, socket) do
    if socket.assigns.show_trait_search do
      {:noreply, close_trait_search(socket)}
    else
      {:noreply, assign(socket, :show_trait_search, true)}
    end
  end

  def handle_event("hide_trait_search", _params, socket) do
    {:noreply, assign(socket, :show_trait_search, false)}
  end

  def handle_event("trait_search", %{"q" => q}, socket) do
    {:noreply, assign_trait_search(socket, q)}
  end

  def handle_event("clear_trait_search", _params, socket) do
    {:noreply,
     socket
     |> assign_trait_search("")
     |> push_patch(to: ~p"/me_file_builder")}
  end

  def handle_event("open_trait", %{"id" => id}, socket) do
    case parse_id(to_string(id)) do
      nil -> {:noreply, socket}
      trait_id -> {:noreply, open_trait_editor(socket, trait_id)}
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
    {:noreply, open_trait_editor(socket, trait_id)}
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
      suggested_traits: Suggestions.suggested_traits_for_me_file(me_file_id)
    }
  end

  # After tags change or a suggestion is dismissed: refresh in place (no
  # skeleton). Search ranking stays; the values on each result update now, so
  # the green confirmation plays over the new tag rather than the old one.
  defp reload_index(socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    socket
    |> assign(:index, AsyncResult.ok(socket.assigns.index, load_index(me_file_id)))
    |> refresh_search_tags(me_file_id)
  end

  defp refresh_search_tags(socket, me_file_id) do
    case socket.assigns.trait_results do
      %AsyncResult{ok?: true, result: results} when is_list(results) ->
        assign(
          socket,
          :trait_results,
          AsyncResult.ok(socket.assigns.trait_results, with_tags(me_file_id, results))
        )

      _ ->
        socket
    end
  end

  # Taxonomy search: traits (and their tag options and search terms) that
  # match, limited to ones in an active survey so each opens an editor. A
  # query too short to search shows the index again. The lookup runs with
  # assign_async, so the first search shows the results skeleton and a
  # follow-up search keeps the rows already on screen.
  defp assign_trait_search(socket, q) do
    q = q |> to_string() |> String.slice(0, @trait_search_max_length)

    case TraitSearch.tokenize(q) do
      {:error, :empty_query} ->
        assign(socket, :trait_search, q)

      {:ok, _} ->
        me_file_id = socket.assigns.current_scope.user.me_file.id
        showing_results? = showing_trait_results?(socket)

        socket =
          socket
          |> assign(:trait_search, q)
          |> assign_async(:trait_results, fn ->
            {:ok, %{trait_results: search_traits(me_file_id, q)}}
          end)

        if showing_results?,
          do: socket,
          else: assign(socket, :trait_results, AsyncResult.loading())
    end
  end

  # Words under 3 characters are not a search. The field still shows them;
  # the results component is left idle, which it cannot render.
  defp searchable?(query), do: match?({:ok, _}, TraitSearch.tokenize(query))

  defp showing_trait_results?(socket) do
    searchable?(socket.assigns.trait_search) and
      match?(%AsyncResult{ok?: true}, socket.assigns.trait_results)
  end

  defp search_traits(me_file_id, q) do
    {:ok, tokens} = TraitSearch.tokenize(q)

    ranked =
      tokens |> TraitSearch.rank(surveyed_only: true) |> Enum.take(@trait_result_limit)

    with_tags(me_file_id, ranked)
  end

  defp with_tags(me_file_id, results) do
    tags = MeFiles.tag_values_by_parent(me_file_id, Enum.map(results, & &1.trait_id))

    Enum.map(results, fn result ->
      values = Map.get(tags, result.trait_id, [])
      Map.merge(result, %{tags: values, tagged?: values != []})
    end)
  end

  defp open_suggestion(socket, suggestion_id) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    case Suggestions.suggested_trait_for_me_file(me_file_id, suggestion_id) do
      nil ->
        put_flash(socket, :info, "That suggestion has already been answered or dismissed.")

      entry ->
        open_trait_editor(socket, entry.trait.id,
          suggested_ids: Enum.map(entry.new_values, & &1.id),
          chat_note: chat_note(entry)
        )
    end
  end

  # Opens a parent trait's tag editor on its own (from a survey, a search
  # result or a suggestion). `suggested_ids` are ticked and highlighted on top
  # of what's on file; nothing is written until Save.
  defp open_trait_editor(socket, trait_id, opts \\ []) do
    me_file_id = socket.assigns.current_scope.user.me_file.id
    {:ok, trait} = Traits.get_trait_with_full_survey_data!(trait_id)
    existing = MeFiles.existing_tags_per_parent_trait(me_file_id, trait_id)
    suggested_ids = Keyword.get(opts, :suggested_ids, [])

    selected_ids =
      selection_with_suggested(trait, Enum.map(existing, & &1.trait_id), suggested_ids)

    socket
    |> assign(:trait_in_edit, trait)
    |> assign(:trait_in_edit_values, Enum.map(existing, & &1.trait.trait_name))
    |> assign(:selected_child_trait_ids, selected_ids)
    |> assign(:highlight_child_ids, suggested_ids)
    |> assign(:chat_note, Keyword.get(opts, :chat_note))
    |> assign(:show_modal_skip, selected_ids == [])
    |> assign(:show_modal, true)
    |> assign(:show_delete_confirm, false)
    |> assign(:show_skip_conflict, false)
    |> ZipCodeLookup.initialize_zip_lookup_assigns()
    |> scroll_tag_list(suggested_ids)
  end

  # Suggested values join what's on file (a skip answer gives way to them);
  # a single-select takes the first suggested value instead.
  defp selection_with_suggested(_trait, existing_ids, []), do: existing_ids

  defp selection_with_suggested(%{input_type: "single_select"}, _existing_ids, [first | _]),
    do: [first]

  defp selection_with_suggested(
         %{input_type: "multi_select"} = trait,
         existing_ids,
         suggested_ids
       ) do
    skip_ids = for child <- trait.child_traits, child.is_skipped_tag, do: child.id
    Enum.uniq((existing_ids -- skip_ids) ++ suggested_ids)
  end

  defp selection_with_suggested(_trait, existing_ids, _suggested_ids), do: existing_ids

  defp scroll_tag_list(socket, []), do: push_event(socket, "scroll-tag-list-to-top", %{})

  defp scroll_tag_list(socket, [first | _]),
    do: push_event(socket, "scroll-tag-option-into-view", %{id: "trait-#{first}"})

  defp chat_note(%{new_values: [_ | _] = values}),
    do: "Ticked from your chat: #{join_names(values)}. Nothing is added until you save."

  defp chat_note(%{suggestion: %{proposed_values: [_ | _] = values}}),
    do: "Mentioned in chat: #{Enum.join(values, ", ")}"

  defp chat_note(_entry), do: nil

  defp join_names(traits), do: traits |> Enum.map(& &1.trait_name) |> Enum.join(", ")

  # What "Related" searches for: a word from chat that named no tag option
  # first (the likeliest gap), else the new value itself.
  defp related_query(%{unmatched_values: [value | _]}), do: value
  defp related_query(%{new_values: [value | _]}), do: value.trait_name
  defp related_query(_entry), do: nil

  attr :results, :list, required: true
  attr :trait_search, :string, required: true
  attr :tag_display_mode, :string, required: true

  # The same list rows and tag chips as /me_file, in that page's current view.
  defp trait_search_results(assigns) do
    parent_traits =
      Enum.map(assigns.results, fn result ->
        tags =
          result.tags
          |> Enum.with_index()
          |> Enum.map(fn {value, index} -> {index, value, index} end)

        {result.trait_id, result.trait, 0, tags}
      end)

    match_notes =
      Map.new(assigns.results, fn result -> {result.trait_id, match_note(result)} end)

    assigns =
      assigns
      |> assign(:parent_traits, parent_traits)
      |> assign(:match_notes, match_notes)
      |> assign(
        :skip_child_ids,
        Traits.active_skipped_child_id_by_parent(Enum.map(parent_traits, &elem(&1, 0)))
      )

    ~H"""
    <section
      id="builder-trait-results"
      class="mefile-category builder-results"
      aria-live="polite"
      phx-hook="AnimateTrait"
    >
      <div class="mefile-category__head">
        <h2>
          Matched Tags<span :if={@parent_traits != []}> ({length(@parent_traits)})</span>
        </h2>
      </div>
      <p :if={@parent_traits == []} class="builder-results__empty">
        No topics match "{@trait_search}".
      </p>
      <.traits_frame :if={@parent_traits != []} tag_display_mode={@tag_display_mode}>
        <.parent_traits_display
          parent_traits={@parent_traits}
          tag_display_mode={@tag_display_mode}
          skip_child_ids={@skip_child_ids}
          match_notes={@match_notes}
          bare={@tag_display_mode != "list"}
        />
      </.traits_frame>
    </section>
    """
  end

  # Cite a tag value only when that value is why the topic is here and it is
  # not already on the card. The topic name and the tag values showing now
  # count, even when a search-term slug outscored that name. A parent search
  # term is quoted because it is not on the card. A category name is the
  # reason only when nothing else matched.
  defp match_note(
         %{matches: matches, trait: trait, matched_values: values, category: category} = result
       ) do
    displayed = [trait | Map.get(result, :tags, [])]
    tokens = matches |> Enum.map(& &1.token) |> Enum.uniq()

    obvious? =
      tokens != [] and
        Enum.all?(tokens, fn token ->
          Enum.any?(displayed, &TraitSearch.obvious?(token, &1))
        end)

    terms =
      matches
      |> Enum.filter(&(&1.field == "search_term"))
      |> Enum.map(& &1.text)
      |> Enum.uniq()

    cond do
      obvious? ->
        nil

      values != [] ->
        "Match: " <> Enum.join(Enum.uniq(values), ", ")

      terms != [] ->
        "Match: " <> Enum.join(terms, ", ")

      Enum.any?(matches, &(&1.field == "category")) and is_binary(category) and category != "" ->
        category

      true ->
        nil
    end
  end

  defp match_note(_), do: nil

  attr :tag_display_mode, :string, required: true

  # Bones in the shape of the view that's about to arrive: list rows in a
  # card, or tag chips on the page.
  defp trait_search_skeleton(assigns) do
    ~H"""
    <section
      id="builder-trait-results-skeleton"
      class="mefile-category builder-results"
      aria-busy="true"
      aria-label="Searching topics"
    >
      <div class="mefile-category__head">
        <h2>Matched Tags</h2>
      </div>
      <.surface_panel :if={@tag_display_mode == "list"} padding={false} class="youdata-card">
        <ul class="mefile-list" aria-hidden="true">
          <li :for={_ <- 1..3} class="mefile-row">
            <div class="min-w-0 flex-1 space-y-2">
              <span class="skeleton h-3 w-24"></span>
              <span class="skeleton h-4 w-40"></span>
            </div>
          </li>
        </ul>
      </.surface_panel>
      <div :if={@tag_display_mode != "list"} class="flex flex-row flex-wrap gap-2" aria-hidden="true">
        <span :for={_ <- 1..3} class="skeleton h-14 w-36 rounded-lg"></span>
      </div>
    </section>
    """
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

  # Observed entries: an assistant's read hit a gap; the rest it proposed.
  defp suggestion_byline(%{suggestion: %{source: "observed"}}), do: "Asked about by"
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
