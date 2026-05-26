defmodule QlariusWeb.MeFileHTML do
  use QlariusWeb, :html

  embed_templates "me_file_html/*"

  def progress_bar_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500"
      percentage > 0 -> "bg-orange-500"
      true -> "bg-red-500"
    end
  end

  def badge_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500 text-white"
      percentage > 0 -> "bg-orange-500 text-white"
      true -> "bg-red-500 text-white"
    end
  end

  attr :tag_count, :integer, required: true
  attr :trait_count, :integer, required: true

  def tag_and_trait_count_badges(assigns) do
    ~H"""
    <div class="flex gap-4 mb-6">
      <div class="bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content px-4 py-2 font-medium rounded-lg text-sm border border-youdata-300 dark:border-youdata-500">
        {@tag_count} tags
      </div>
      <%!-- <div class="bg-base-100 text-base-content px-3 py-1 rounded-full text-sm border border-neutral-300 dark:border-neutral-500">
        {@tag_count} tags
      </div> --%>
    </div>
    """
  end

  attr :trait_in_edit, :any, default: nil
  attr :me_file_id, :integer, required: true
  attr :selected_ids, :list, default: []
  attr :show_modal, :boolean, default: false
  attr :show_delete_confirm, :boolean, default: false
  attr :zip_lookup_input, :string, default: ""
  attr :zip_lookup_trait, :any, default: nil
  attr :zip_lookup_valid, :boolean, default: false
  attr :zip_lookup_error, :string, default: nil
  attr :dual_pane, :boolean, default: false
  attr :show_expanded_tags, :boolean, default: false
  attr :is_pwa, :boolean, default: false

  def tag_edit_modal(assigns) do
    ~H"""
    <div
      class={[
        "modal modal-bottom tag-edit-modal",
        @dual_pane && "modal-dual-pane",
        @show_modal && "modal-open"
      ]}
      aria-hidden={not @show_modal}
    >
      <div class="modal-backdrop tag-edit-modal__backdrop">
        <button type="button" phx-click="close_modal" aria-label="Close modal">
          close
        </button>
      </div>
      <div class={[
        "tag-edit-modal__box modal-box flex flex-col bg-base-100 p-0 overflow-hidden",
        "border-x border-b border-youdata-200 dark:border-base-content/10",
        @is_pwa && "max-h-[calc(90vh-env(safe-area-inset-top))]",
        !@is_pwa && "max-h-[90vh]"
      ]}>
        <%!-- Trait-card style header --%>
        <div class="border-t-4 border-youdata-500 bg-base-300/50 dark:bg-base-700/45 shrink-0 px-4 py-3 flex flex-row justify-between items-center gap-3">
          <h3 class="min-w-0 text-lg font-bold leading-tight text-youdata-800 dark:text-youdata-200">
            {if @trait_in_edit, do: @trait_in_edit.trait_name, else: "Edit Trait"}
          </h3>
          <button
            type="button"
            phx-click="close_modal"
            class="flex h-9 w-9 shrink-0 cursor-pointer items-center justify-center rounded-full bg-base-200 dark:bg-base-300/70 border border-base-300/80 dark:border-base-content/10 text-base-content/60 hover:text-base-content hover:bg-base-300 dark:hover:bg-base-300/90 transition-colors"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <%!-- Expandable content area --%>
        <%= if @trait_in_edit do %>
            <%!-- Question section --%>
            <div class="p-4 bg-base-100 text-base-content/70 shrink-0 border-b border-base-300/40 dark:border-base-content/10">
              <p :if={@trait_in_edit && @trait_in_edit.survey_question} class="text-lg mb-3">
                {Phoenix.HTML.raw(@trait_in_edit.survey_question.text)}
              </p>

              <%!-- Toggle for expanded/simple view - only show if there are meaningful expanded answers --%>
              <.pill_join_selector
                :if={
                  @trait_in_edit.input_type != "single_select_zip" &&
                    Ecto.assoc_loaded?(@trait_in_edit.child_traits) &&
                    Enum.any?(@trait_in_edit.child_traits, fn child ->
                      child.survey_answer &&
                        child.survey_answer.text not in [nil, ""] &&
                        child.survey_answer.text != child.trait_name
                    end)
                }
                label="Tag list view"
                class="mt-2"
              >
                <.pill_join_item
                  active={!@show_expanded_tags}
                  phx-click="set_tag_view"
                  phx-value-expanded="false"
                  aria-pressed={to_string(!@show_expanded_tags)}
                >
                  Simple
                </.pill_join_item>
                <.pill_join_item
                  active={@show_expanded_tags}
                  phx-click="set_tag_view"
                  phx-value-expanded="true"
                  aria-pressed={to_string(@show_expanded_tags)}
                >
                  Expanded
                </.pill_join_item>
              </.pill_join_selector>
            </div>
            <.form
              for={%{}}
              phx-change="sync_tag_selection"
              phx-submit="save_tags"
              class="flex flex-col flex-1 min-h-0"
            >
              <div
                id="tag-list-scroll-container"
                class="flex-1 overflow-y-auto p-4"
              >
                <input type="hidden" name="me_file_id" value={@me_file_id} />
                <input type="hidden" name="trait_id" value={@trait_in_edit.id} />
                <div
                  :if={@trait_in_edit.input_type == "single_select_zip"}
                  class="space-y-4"
                >
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text text-lg mb-2">Enter 5-digit zip code:</span>
                    </label>
                    <input
                      type="text"
                      name="zip_code_input"
                      value={@zip_lookup_input}
                      phx-change="lookup_zip_code"
                      maxlength="5"
                      pattern="\d{5}"
                      inputmode="numeric"
                      autocomplete="postal-code"
                      data-1p-ignore="true"
                      data-lpignore="true"
                      data-form-type="other"
                      class="input input-bordered input-xl w-full text-xl"
                    />
                  </div>

                  <div class="min-h-[4rem]">
                    <div :if={@zip_lookup_trait && @zip_lookup_valid} class="space-y-2">
                      <div class="badge badge-primary badge-lg p-4">
                        <.icon name="hero-map-pin" class="w-5 h-5" />
                        {@zip_lookup_trait.meta_1}
                      </div>
                      <input
                        type="hidden"
                        name="child_trait_ids[]"
                        value={@zip_lookup_trait.id}
                      />
                    </div>

                    <div :if={@zip_lookup_error} class="alert alert-error">
                      <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
                      <span>{@zip_lookup_error}</span>
                    </div>
                  </div>
                </div>
                <div
                  :if={
                    @trait_in_edit.input_type != "single_select_zip" &&
                      Ecto.assoc_loaded?(@trait_in_edit.child_traits) &&
                      @trait_in_edit.child_traits != []
                  }
                  class="py-0"
                >
                  <label
                    :for={
                      child_trait <- Enum.sort_by(@trait_in_edit.child_traits, & &1.display_order)
                    }
                    class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 py-4 px-2 hover:bg-base-200 cursor-pointer"
                  >
                    <input
                      :if={@trait_in_edit.input_type == "single_select"}
                      type="radio"
                      name="child_trait_ids[]"
                      value={child_trait.id}
                      id={"trait-#{child_trait.id}"}
                      checked={child_trait.id in @selected_ids}
                      class="radio w-7 h-7"
                    />
                    <input
                      :if={@trait_in_edit.input_type == "multi_select"}
                      type="checkbox"
                      name="child_trait_ids[]"
                      value={child_trait.id}
                      id={"trait-#{child_trait.id}"}
                      checked={child_trait.id in @selected_ids}
                      class="checkbox w-7 h-7"
                    />
                    <div class="flex-1">
                      <div class="text-lg text-base-content font-medium">
                        {child_trait.trait_name}
                      </div>
                      <div
                        :if={
                          @show_expanded_tags &&
                            child_trait.survey_answer &&
                            child_trait.survey_answer.text not in [nil, ""] &&
                            child_trait.survey_answer.text != child_trait.trait_name
                        }
                        class="text-sm text-base-content/60 mt-1"
                      >
                        {child_trait.survey_answer.text}
                      </div>
                    </div>
                  </label>
                </div>
              </div>

              <%!-- Footer + delete confirm strip (slides up behind the button bar) --%>
              <div class="relative shrink-0">
                <div
                  class={[
                    "overflow-hidden transition-[max-height] duration-200 ease-out",
                    @show_delete_confirm && "max-h-28",
                    !@show_delete_confirm && "max-h-0"
                  ]}
                  aria-hidden={!@show_delete_confirm}
                >
                  <div class="bg-error text-error-content px-6 py-4 border-t border-error/60">
                    <p class="text-sm font-semibold mb-3">
                      Delete {length(@selected_ids)} selected tag{if length(@selected_ids) == 1,
                        do: "",
                        else: "s"}?
                    </p>
                    <div class="flex flex-row gap-2 justify-end">
                      <button
                        type="button"
                        phx-click="cancel_delete_confirm"
                        class="btn btn-sm btn-ghost rounded-full text-error-content hover:bg-error-content/15"
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        phx-click="confirm_delete_tags"
                        class="btn btn-sm rounded-full bg-error-content text-error hover:bg-error-content/90"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>

                <div class="relative z-10 py-4 px-6 flex flex-row items-center justify-between gap-3 bg-base-200 border-t border-base-300">
                  <div class="shrink-0">
                    <button
                      :if={deletable_trait?(@trait_in_edit)}
                      type="button"
                      phx-click="request_delete_confirm"
                      class={[
                        "btn btn-circle btn-lg btn-ghost text-error hover:bg-error/10",
                        @show_delete_confirm && "btn-active bg-error/10"
                      ]}
                      disabled={length(@selected_ids) == 0}
                      aria-label="Delete selected tags"
                      aria-expanded={to_string(@show_delete_confirm)}
                    >
                      <.icon name="hero-trash" class="h-6 w-6" />
                    </button>
                  </div>
                  <div class="flex flex-row items-center gap-2 justify-end min-w-0">
                    <button
                      type="button"
                      phx-click="close_modal"
                      class="btn btn-lg btn-ghost rounded-full"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="btn btn-lg btn-primary rounded-full"
                      disabled={@trait_in_edit.input_type == "single_select_zip" && !@zip_lookup_valid}
                    >
                      Save/Update Tags
                    </button>
                  </div>
                </div>
              </div>
            </.form>
        <% else %>
            <div class="flex-1 flex items-center justify-center p-8">
              <div class="text-base-content/50">No trait selected</div>
            </div>
        <% end %>
      </div>
      <%!-- <pre :if={@trait_in_edit} class="py-4 overflow-auto max-h-96 whitespace-pre-wrap bg-base-200 rounded-lg p-4">{inspect(@trait_in_edit, pretty: true, width: 60)}</pre> --%>
    </div>
    """
  end

  attr :tag_search, :string, required: true
  attr :autofocus, :boolean, default: false
  attr :compact, :boolean, default: false

  def tag_search_input(assigns) do
    ~H"""
    <form phx-change="tag_search_changed" class="flex-1 min-w-0 w-full">
      <label class={[
        "input flex w-full items-center min-w-0 shadow-lg bg-base-100 dark:bg-base-200 border-base-300",
        @compact && "input-lg gap-3 rounded-full px-4",
        !@compact && "input-bordered input-md gap-2"
      ]}>
        <.icon
          name="hero-magnifying-glass"
          class={if(@compact, do: "opacity-50 shrink-0 h-5 w-5", else: "opacity-50 shrink-0 h-4 w-4")}
        />
        <input
          id="mefile-tag-search-input"
          type="text"
          name="tag_search"
          value={@tag_search}
          inputmode="search"
          enterkeyhint="search"
          role="searchbox"
          autocomplete="off"
          aria-label="Search tags"
          autofocus={@autofocus}
          class={[
            "grow min-w-0 bg-transparent outline-none",
            @compact && "text-lg",
            !@compact && "text-base"
          ]}
        />
        <button
          :if={@tag_search != ""}
          type="button"
          phx-click="clear_tag_search"
          class={[
            "btn btn-ghost btn-circle shrink-0",
            @compact && "btn-sm",
            !@compact && "btn-xs"
          ]}
          aria-label="Clear search text"
        >
          <.icon name="hero-x-mark" class={if(@compact, do: "h-5 w-5", else: "h-4 w-4")} />
        </button>
      </label>
    </form>
    """
  end

  attr :tag_search, :string, required: true
  attr :tag_display_mode, :string, required: true
  attr :show_tag_search, :boolean, required: true
  attr :show_view_menu, :boolean, required: true
  attr :show_add_tags, :boolean, default: true
  attr :show_search, :boolean, default: true

  def mefile_floating_toolbar(assigns) do
    assigns = assign(assigns, :compact_toolbar?, !assigns.show_add_tags && !assigns.show_search)

    ~H"""
    <div
      id="mefile-floating-toolbar"
      class="fixed right-4 bottom-[5.75rem] z-40 max-w-[calc(100vw-2rem)] pointer-events-none"
    >
      <div
        id="mefile-floating-toolbar-inner"
        phx-click-away={@show_search && @show_tag_search && "hide_tag_search"}
        class="flex flex-col items-end gap-2 pointer-events-auto"
      >
        <div
          :if={@show_search && @show_tag_search}
          id="mefile-tag-search-panel"
          class="w-full min-w-[16rem] max-w-[calc(100vw-2rem)]"
          phx-mounted={JS.dispatch("phx:focus", detail: %{id: "mefile-tag-search-input"})}
        >
          <.tag_search_input tag_search={@tag_search} autofocus={true} compact={true} />
        </div>

        <.mefile_view_mode_menu
          :if={@show_view_menu && @compact_toolbar?}
          tag_display_mode={@tag_display_mode}
        />

        <div class="flex flex-row items-center justify-end gap-2">
        <button
          :if={@show_search}
          type="button"
          phx-click="toggle_tag_search"
          class={mefile_fab_class(@show_tag_search)}
          aria-label="Search tags"
          aria-expanded={to_string(@show_tag_search)}
        >
          <.icon name="hero-magnifying-glass" class="h-5 w-5" />
        </button>
        <div class="relative shrink-0">
          <.mefile_view_mode_menu
            :if={@show_view_menu && !@compact_toolbar?}
            tag_display_mode={@tag_display_mode}
            class="absolute bottom-full right-0 z-50 mb-2"
          />
          <button
            type="button"
            phx-click="toggle_view_menu"
            class={mefile_fab_class(@show_view_menu)}
            aria-label={"View: #{tag_display_mode_label(@tag_display_mode)}"}
            aria-expanded={to_string(@show_view_menu)}
          >
            <.icon name={tag_display_mode_icon(@tag_display_mode)} class="h-5 w-5" />
          </button>
        </div>
        <.link
          :if={@show_add_tags}
          navigate={~p"/me_file_builder"}
          class="btn btn-primary btn-lg rounded-full flex items-center gap-1 px-4 py-5 shadow-lg"
        >
          <.icon name="hero-plus" class="h-5 w-5" /> Add tags
        </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :tag_display_mode, :string, required: true
  attr :class, :string, default: ""

  def mefile_view_mode_menu(assigns) do
    ~H"""
    <div
      class={[
        "rounded-2xl border border-base-300 bg-base-100 dark:bg-base-200 shadow-lg p-2 flex flex-row gap-1 shrink-0",
        @class
      ]}
      role="menu"
      aria-label="Tag display mode"
    >
      <button
        :for={mode <- ~w(tag block list)}
        type="button"
        phx-click="set_tag_display_mode"
        phx-value-mode={mode}
        class={[
          "btn btn-sm btn-square btn-ghost",
          @tag_display_mode == mode && "bg-youdata-300/50 dark:bg-youdata-800/50"
        ]}
        aria-label={tag_display_mode_label(mode)}
        aria-current={@tag_display_mode == mode && "true"}
        role="menuitem"
      >
        <.icon name={tag_display_mode_icon(mode)} class="h-5 w-5" />
      </button>
    </div>
    """
  end

  attr :tag_display_mode, :string, required: true

  def tag_display_mode_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end shrink-0">
      <div
        tabindex="0"
        role="button"
        class="btn btn-ghost btn-sm btn-square"
        aria-label={"Tag display: #{tag_display_mode_label(@tag_display_mode)}"}
      >
        <.icon name={tag_display_mode_icon(@tag_display_mode)} class="h-5 w-5" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-50 mt-1 w-auto min-w-0 border border-base-300 p-1 shadow-lg"
      >
        <li :for={mode <- ~w(tag block list)}>
          <button
            type="button"
            phx-click="set_tag_display_mode"
            phx-value-mode={mode}
            class={[
              "btn btn-ghost btn-sm btn-square",
              @tag_display_mode == mode && "active bg-youdata-300/50 dark:bg-youdata-800/50"
            ]}
            aria-label={tag_display_mode_label(mode)}
            aria-current={@tag_display_mode == mode && "true"}
          >
            <.icon name={tag_display_mode_icon(mode)} class="h-5 w-5" />
          </button>
        </li>
      </ul>
    </div>
    """
  end

  attr :parent_traits, :list, required: true
  attr :tag_display_mode, :string, required: true
  attr :readonly, :boolean, default: false

  def parent_traits_display(assigns) do
    assigns =
      assign(
        assigns,
        :inset_class,
        if(assigns.readonly, do: "p-4", else: "px-4 pb-4")
      )

    ~H"""
    <%= case @tag_display_mode do %>
      <% "list" -> %>
        <ul class={[
          "divide-y divide-base-300/60 dark:divide-base-content/10 list-trait-cards",
          if(@readonly, do: @inset_class, else: "pb-4")
        ]}>
          <li
            :for={
              {parent_trait_id, parent_trait_name, _parent_trait_display_order, tags_traits} <-
                @parent_traits
            }
            id={"trait-card-#{parent_trait_id}"}
            class={[
              "trait-card-animate relative flex items-stretch gap-3 px-4 py-3",
              !@readonly && editable_parent_trait?(parent_trait_name) &&
                "cursor-pointer transition-colors duration-200 hover:bg-base-200/40 dark:hover:bg-base-300/20"
            ]}
            phx-click={
              !@readonly && editable_parent_trait?(parent_trait_name) && "edit_tags"
            }
            phx-value-id={
              !@readonly && editable_parent_trait?(parent_trait_name) && parent_trait_id
            }
          >
            <div class="w-[34%] max-w-[9rem] shrink-0 flex items-start pt-2.5">
              <span class={[
                "text-base font-bold leading-tight",
                tags_traits == [] && "text-base-content/65 dark:text-base-content/75",
                tags_traits != [] && "text-base-content"
              ]}>
                {parent_trait_name}
              </span>
            </div>
            <div
              class={[
                "flex flex-1 min-w-0 items-stretch rounded-lg overflow-hidden",
                "bg-base-200 dark:bg-base-300/55",
                tags_traits == [] && "empty-trait-header-strobe"
              ]}
              style={tags_traits == [] && "--animation-delay: #{rem(abs(parent_trait_id), 2000)}ms"}
            >
              <div class="w-1 shrink-0 bg-youdata-500" aria-hidden="true"></div>
              <div class="flex flex-1 min-w-0 items-center justify-between gap-2 px-3 py-2.5">
                <div class="min-w-0 flex-1">
                  <ul :if={tags_traits != []} class="space-y-0.5">
                    <li
                      :for={{_tag_id, tag_value, _display_order} <- tags_traits}
                      class="text-sm leading-snug text-base-content/85"
                    >
                      {tag_value}
                    </li>
                  </ul>
                  <p
                    :if={tags_traits == []}
                    class="text-sm leading-snug italic text-base-content/45"
                  >
                    {QlariusWeb.Components.TraitComponents.empty_tag_tease_message()}
                  </p>
                </div>
                <.trait_actions
                  parent_trait_id={parent_trait_id}
                  parent_trait_name={parent_trait_name}
                  editable={!@readonly}
                  nav_indicator={if(@readonly, do: "none", else: "chevron")}
                  actions_class="flex shrink-0 self-center"
                />
              </div>
            </div>
          </li>
        </ul>
      <% "block" -> %>
        <div class={[
          "grid gap-3",
          @inset_class,
          block_grid_cols_class(@readonly)
        ]}>
          <.trait_card
            :for={
              {parent_trait_id, parent_trait_name, _parent_trait_display_order, tags_traits} <-
                @parent_traits
            }
            parent_trait_id={parent_trait_id}
            parent_trait_name={parent_trait_name}
            tags_traits={tags_traits}
            clickable={!@readonly}
            editable={!@readonly}
            nav_indicator={if(@readonly, do: "none", else: "chevron")}
            display_mode="block"
            extra_classes={if(@readonly, do: "h-full !shadow-none", else: "h-full")}
          />
        </div>
      <% _ -> %>
        <div class={[
          "flex flex-row flex-wrap",
          @inset_class,
          @readonly && "gap-3",
          !@readonly && "gap-4"
        ]}>
          <.trait_card
            :for={
              {parent_trait_id, parent_trait_name, _parent_trait_display_order, tags_traits} <-
                @parent_traits
            }
            parent_trait_id={parent_trait_id}
            parent_trait_name={parent_trait_name}
            tags_traits={tags_traits}
            clickable={!@readonly}
            editable={!@readonly}
            nav_indicator={if(@readonly, do: "none", else: "chevron")}
            display_mode="tag"
            extra_classes={@readonly && "!shadow-none"}
          />
        </div>
    <% end %>
    """
  end

  attr :parent_traits, :list, required: true
  attr :tag_display_mode, :string, required: true
  attr :tag_search, :string, default: ""

  def survey_traits_display(assigns) do
    assigns =
      assign(
        assigns,
        :parent_traits,
        filter_parent_traits_by_search(assigns.parent_traits, assigns.tag_search)
      )

    ~H"""
    <div id="mefilebuilder-tags-display" phx-hook="AnimateTrait">
      <div
        :if={@parent_traits == [] and tag_search_active?(@tag_search)}
        class="text-center py-12 text-base-content/60"
      >
        <p>No tags match your search.</p>
      </div>
      <.parent_traits_display
        :if={@parent_traits != []}
        parent_traits={@parent_traits}
        tag_display_mode={@tag_display_mode}
      />
    </div>
    """
  end

  attr :tag_display_map, :any, required: true
  attr :tag_display_mode, :string, required: true
  attr :tag_search, :string, default: ""
  attr :tag_search_epoch, :integer, default: 0

  def tags_display(assigns) do
    ~H"""
    <div
      id="mefile-tags-display"
      phx-hook="AnimateTrait"
      phx-key={@tag_search_epoch}
      class="flex flex-col gap-10"
    >
      <div
        :if={Enum.empty?(@tag_display_map) and tag_search_active?(@tag_search)}
        class="text-center py-12 text-base-content/60"
      >
        <p>No tags match your search.</p>
      </div>
      <.surface_panel
        :for={{{_id, name, _display_order}, parent_traits} <- @tag_display_map}
        padding={false}
      >
        <div class="flex justify-between items-center px-4 pt-4 pb-3">
          <h2 class="text-lg font-bold tracking-tight text-base-content/50">
            {name}
          </h2>
          <span class="text-sm text-base-content/50">
            <% tag_count = length(parent_traits) %>
            {tag_count} {plural_tag_word(tag_count)}
          </span>
        </div>

        <.parent_traits_display parent_traits={parent_traits} tag_display_mode={@tag_display_mode} />
      </.surface_panel>
    </div>
    """
  end

  @doc """
  Filters the me-file tag map by search text.

  When a parent trait name or any child tag value matches, the full parent
  entry (all child tags) is kept. Categories with no matching parents are omitted.
  """
  def filter_parent_traits_by_search(parent_traits, search) when search in [nil, ""],
    do: parent_traits

  def filter_parent_traits_by_search(parent_traits, search) do
    needle =
      search
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if needle == "" do
      parent_traits
    else
      Enum.filter(parent_traits, &parent_trait_matches_search?(&1, needle))
    end
  end

  def filter_tag_map_by_search(tag_categories, search) when search in [nil, ""],
    do: normalize_tag_categories(tag_categories)

  def filter_tag_map_by_search(tag_categories, search) do
    needle =
      search
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if needle == "" do
      normalize_tag_categories(tag_categories)
    else
      tag_categories
      |> normalize_tag_categories()
      |> Enum.map(fn {category, parent_traits} ->
        {category, Enum.filter(parent_traits, &parent_trait_matches_search?(&1, needle))}
      end)
      |> Enum.reject(fn {_category, parent_traits} -> parent_traits == [] end)
    end
  end

  defp normalize_tag_categories(tag_categories) when is_list(tag_categories), do: tag_categories

  defp normalize_tag_categories(tag_categories) when is_map(tag_categories) do
    tag_categories
    |> Map.to_list()
    |> Enum.sort_by(fn {{_id, name, display_order}, _parent_traits} -> [display_order, name] end)
  end

  defp parent_trait_matches_search?({_id, parent_name, _order, tags_traits}, needle) do
    text_matches_search?(parent_name, needle) or
      Enum.any?(tags_traits, fn {_id, tag_value, _order} ->
        text_matches_search?(tag_value, needle)
      end)
  end

  defp text_matches_search?(text, needle) do
    text
    |> to_string()
    |> String.downcase()
    |> String.contains?(needle)
  end

  defp tag_search_active?(search) do
    search |> to_string() |> String.trim() != ""
  end

  @protected_trait_names ["Birthdate", "Age", "Sex (Bio)"]

  defp deletable_trait?(%{trait_name: name}), do: editable_parent_trait?(name)
  defp deletable_trait?(_), do: false

  defp editable_parent_trait?(name), do: name not in @protected_trait_names

  defp mefile_fab_class(active?) do
    [
      "btn btn-lg btn-circle shadow-lg border border-base-300",
      "bg-base-100 dark:bg-base-200 text-base-content",
      "hover:bg-base-200 dark:hover:bg-base-300",
      active? && "ring-2 ring-youdata-500/60"
    ]
  end

  defp plural_tag_word(1), do: "tag"
  defp plural_tag_word(_), do: "tags"

  defp block_grid_cols_class(true), do: "grid-cols-2"

  defp block_grid_cols_class(false) do
    "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-7"
  end

  defp tag_display_mode_label("tag"), do: "Tags"
  defp tag_display_mode_label("block"), do: "Blocks"
  defp tag_display_mode_label("list"), do: "List"
  defp tag_display_mode_label(_), do: "Tags"

  defp tag_display_mode_icon("tag"), do: "hero-tag"
  defp tag_display_mode_icon("block"), do: "hero-squares-2x2"
  defp tag_display_mode_icon("list"), do: "hero-bars-3-bottom-left"
  defp tag_display_mode_icon(_), do: "hero-tag"

end
