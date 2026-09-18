defmodule QlariusWeb.Components.Targeting do
  use QlariusWeb, :html

  alias Qlarius.Sponster.Campaigns.{TargetBand, Targets}

  def copy(:target) do
    %{
      noun: "Target",
      noun_lower: "target",
      populate: "Freeze and Populate Target",
      populate_confirm: "This will calculate populations for all bands. Continue?",
      expand: "Expand Target",
      empty_hint:
        "Start by creating a bullseye for this target. Select trait groups from the panel on the right.",
      picker_heading: "Select a Trait Group to add to the Bullseye:",
      none_available:
        "No available trait groups. All trait groups have been added to this target.",
      locked_title: "This target structure is frozen",
      locked_body: "Depopulate this target below to edit its structure.",
      refresh: "Refresh Population",
      depopulate: "Depopulate"
    }
  end

  def copy(:audience) do
    %{
      noun: "Audience",
      noun_lower: "audience",
      populate: "Populate audience",
      populate_confirm: "This will calculate who is in this audience. Continue?",
      expand: "Expand audience",
      empty_hint:
        "Start by tagging your content, or add a trait group from the panel on the right.",
      picker_heading: "Select a trait group to add to the bullseye:",
      none_available:
        "No available trait groups. All trait groups have been added to this audience.",
      locked_title: "This audience structure is frozen",
      locked_body: "Depopulate this audience to edit its structure.",
      refresh: "Refresh reach",
      depopulate: "Depopulate"
    }
  end

  def trait_ids_from_params(params) when is_map(params) do
    params
    |> Map.get("trait_ids", [])
    |> List.wrap()
    |> Enum.flat_map(fn
      id when is_integer(id) ->
        [id]

      id when is_binary(id) ->
        case Integer.parse(id) do
          {int, ""} -> [int]
          _ -> []
        end

      _ ->
        []
    end)
  end

  def trait_ids_target?(target) do
    List.first(List.wrap(target)) in ["trait_ids", "trait_ids[]"]
  end

  def excluded_trait_group_id(band, bands) do
    sorted_bands = Enum.sort_by(bands, &length(&1.trait_groups), :desc)
    current_index = Enum.find_index(sorted_bands, &(&1.id == band.id))

    if current_index && current_index < length(sorted_bands) - 1 do
      next_band = Enum.at(sorted_bands, current_index + 1)
      current_tg_ids = Enum.map(band.trait_groups, & &1.id) |> MapSet.new()
      next_tg_ids = Enum.map(next_band.trait_groups, & &1.id) |> MapSet.new()

      MapSet.difference(current_tg_ids, next_tg_ids)
      |> MapSet.to_list()
      |> List.first()
    end
  end

  attr :copy, :map, required: true
  attr :bands, :list, required: true
  attr :outermost_band, :any, required: true
  attr :available_trait_groups, :list, required: true
  attr :expanding_target, :boolean, default: false
  attr :show_populate?, :boolean, default: true

  def band_editor(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2">
        <%= if @bands == [] do %>
          <div class="alert alert-info mb-6">
            <.icon name="hero-information-circle" class="w-6 h-6" />
            <span>{@copy.empty_hint}</span>
          </div>
        <% end %>

        <div class="mb-6 flex gap-2">
          <button type="button" phx-click="done" class="btn btn-primary">Done</button>
          <button
            :if={@show_populate? and @bands != []}
            type="button"
            phx-click="populate_target"
            class="btn btn-success"
            data-confirm={@copy.populate_confirm}
          >
            {@copy.populate}
          </button>
        </div>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Rings</th>
                <th>Trait Groups</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={band <- @bands}>
                <td class={[
                  "font-bold !align-top",
                  TargetBand.is_bullseye?(band) && "text-error"
                ]}>
                  <div class="flex items-start gap-2">
                    <span>{Targets.band_label(band, @bands)}</span>
                    <button
                      :if={
                        @outermost_band && band.id == @outermost_band.id &&
                          !TargetBand.is_bullseye?(@outermost_band)
                      }
                      type="button"
                      phx-click="delete_outermost_band"
                      class="btn btn-ghost btn-xs btn-circle"
                      title="Delete this ring"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </td>
                <td class="!align-top">
                  <div class="space-y-2">
                    <%= if @expanding_target && @outermost_band && band.id == @outermost_band.id &&
                          length(band.trait_groups) > 1 do %>
                      <div class="flex flex-wrap gap-2">
                        <button
                          :for={tg <- band.trait_groups}
                          type="button"
                          phx-click="create_outer_band"
                          phx-value-excluded_trait_group_id={tg.id}
                          class={[
                            "badge badge-warning cursor-pointer py-3 px-3",
                            tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                          ]}
                          title={"Click to exclude #{tg.title}"}
                        >
                          {tg.title} <.icon name="hero-scissors" class="w-4 h-4" />
                        </button>
                      </div>
                    <% else %>
                      <%= if TargetBand.is_bullseye?(band) && length(@bands) == 1 do %>
                        <div class="flex flex-wrap gap-2">
                          <div
                            :for={tg <- band.trait_groups}
                            class="badge badge-outline py-3 px-3 flex items-center gap-2"
                          >
                            <span>{tg.title}</span>
                            <button
                              type="button"
                              phx-click="remove_trait_group_from_bullseye"
                              phx-value-band_id={band.id}
                              phx-value-trait_group_id={tg.id}
                              class="cursor-pointer hover:text-error"
                              title="Remove from bullseye"
                            >
                              <.icon name="hero-x-mark" class="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                      <% else %>
                        <div class="flex flex-wrap gap-2">
                          <span
                            :for={tg <- band.trait_groups}
                            class={[
                              "badge badge-outline py-3",
                              tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                            ]}
                          >
                            {tg.title}
                          </span>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                </td>
              </tr>
              <tr :if={@expanding_target}>
                <td class="!align-top font-bold text-error">
                  <div class="flex items-start gap-2">
                    <span>Ring {length(@bands)}</span>
                    <button
                      type="button"
                      phx-click="cancel_expanding_target"
                      class="btn btn-ghost btn-xs btn-circle"
                      title="Cancel"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                </td>
                <td class="italic text-base-content/60 !align-top">
                  Select a trait group from the ring above to exclude for this new ring.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          :if={
            @bands != [] && @outermost_band && length(@outermost_band.trait_groups) > 1 &&
              !@expanding_target
          }
          class="mt-6 flex gap-2"
        >
          <button type="button" phx-click="start_expanding_target" class="btn btn-primary btn-outline">
            <.icon name="hero-plus" class="w-5 h-5" /> {@copy.expand}
          </button>
        </div>
      </div>

      <div class="lg:col-span-1">
        <div class="card bg-base-100 dark:bg-base-200 border border-base-300">
          <div class="card-body">
            <h2 class="text-lg font-bold mb-4">{@copy.picker_heading}</h2>

            <%= if length(@bands) > 1 do %>
              <div class="alert alert-neutral mb-4">
                <.icon name="hero-lock-closed" class="w-5 h-5" />
                <div class="text-sm">
                  <p class="font-semibold">Bullseye Locked</p>
                  <p class="text-xs">Delete outer rings first to modify the bullseye.</p>
                </div>
              </div>

              <%= if @available_trait_groups == [] do %>
                <p class="text-sm text-base-content/50">{@copy.none_available}</p>
              <% else %>
                <div class="space-y-2">
                  <div
                    :for={tg <- @available_trait_groups}
                    class="btn btn-sm btn-block justify-start btn-disabled opacity-60"
                  >
                    {tg.title}
                  </div>
                </div>
              <% end %>
            <% else %>
              <%= if @available_trait_groups == [] do %>
                <p class="text-sm text-base-content/50">{@copy.none_available}</p>
              <% else %>
                <div class="space-y-2">
                  <button
                    :for={tg <- @available_trait_groups}
                    type="button"
                    phx-click="add_trait_group"
                    phx-value-trait_group_id={tg.id}
                    class="btn btn-sm btn-block justify-start"
                  >
                    [+] {tg.title}
                  </button>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :copy, :map, required: true
  attr :bands, :list, required: true
  attr :band_population_counts, :map, required: true
  attr :show_frozen_note?, :boolean, default: true

  def population_inspect(assigns) do
    total = assigns.band_population_counts |> Map.values() |> Enum.sum()
    assigns = assign(assigns, :total_population, total)

    ~H"""
    <div>
      <div class="mb-6 flex gap-2">
        <button type="button" phx-click="done" class="btn btn-primary">Done</button>
        <button
          type="button"
          phx-click="refresh_population"
          class="btn btn-success"
          data-confirm="This will recalculate populations for all rings. Continue?"
        >
          {@copy.refresh}
        </button>
        <button
          type="button"
          phx-click="depopulate_target"
          class="btn btn-error btn-outline"
          data-confirm="This will delete all population data. Continue?"
        >
          {@copy.depopulate}
        </button>
      </div>

      <div class="mb-4 p-4 bg-base-200 dark:bg-base-300/55 rounded-lg">
        <p class="text-sm font-semibold">Total Population: {@total_population}</p>
      </div>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Rings</th>
              <th>Trait Groups</th>
              <th class="text-center">People</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={band <- @bands}>
              <td class={[
                "font-bold !align-top",
                TargetBand.is_bullseye?(band) && "text-error"
              ]}>
                <span>{Targets.band_label(band, @bands)}</span>
              </td>
              <td class="!align-top">
                <div class="flex flex-wrap gap-2">
                  <span
                    :for={tg <- band.trait_groups}
                    class={[
                      "badge badge-outline py-3",
                      tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                    ]}
                  >
                    {tg.title}
                  </span>
                </div>
              </td>
              <td class="text-center !align-top">
                <span class="font-semibold">{Map.get(@band_population_counts, band.id, 0)}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@show_frozen_note?} class="alert alert-neutral mt-6">
        <.icon name="hero-lock-closed" class="w-5 h-5" />
        <div class="text-sm">
          <p class="font-semibold">{@copy.locked_title}</p>
          <p class="text-xs">{@copy.locked_body}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :show_modal, :boolean, required: true
  attr :parent_trait, :any, required: true
  attr :form, :any, required: true
  attr :zip_search_term, :string, default: ""
  attr :zip_search_results, :list, default: []
  attr :selected_zips, :list, default: []
  attr :zip_search_limit, :any, default: 1000
  attr :heading, :string, default: nil
  attr :submit_label, :string, default: "Create Trait Group"
  attr :selected_ids, :list, default: []

  def trait_group_modal(assigns) do
    assigns =
      assign(
        assigns,
        :heading,
        assigns.heading || "Create Trait Group: #{assigns.parent_trait.trait_name}"
      )

    ~H"""
    <div class={[
      "modal modal-bottom sm:modal-middle",
      @show_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
    ]}>
      <div class={[
        "flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0 max-h-[90vh]",
        @parent_trait.input_type == "single_select_zip" && "!max-w-3xl"
      ]}>
        <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content shrink-0">
          <h3 class="text-lg font-bold">{@heading}</h3>
          <button type="button" phx-click="close_modal" class="btn btn-md btn-circle btn-ghost">
            ✕
          </button>
        </div>

        <div class="p-4 bg-base-200 text-base-content/70 shrink-0 text-sm">
          <p :if={@parent_trait.survey_question}>
            {Phoenix.HTML.raw(@parent_trait.survey_question.text)}
          </p>
        </div>

        <.form
          for={@form}
          id="trait-group-form"
          phx-change="validate_trait_group"
          phx-submit="save_trait_group"
          class="flex flex-col flex-1 min-h-0"
        >
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <div>
              <.input field={@form[:title]} type="text" label="Trait Group Name" required />
            </div>

            <div>
              <.input field={@form[:description]} type="textarea" label="Description (optional)" />
            </div>

            <%= if @parent_trait.input_type == "single_select_zip" do %>
              <div class="divider">Select Zip Codes</div>

              <div id="zip-selector" phx-hook="ZipSelector" class="flex gap-4 w-full">
                <div class="flex-1 min-w-0">
                  <% available_count =
                    Enum.count(@zip_search_results, fn zip ->
                      not Enum.any?(@selected_zips, &(&1.id == zip.id))
                    end) %>
                  <label class="label">
                    <span class="label-text font-semibold">
                      Available Zip Codes ({available_count})
                    </span>
                  </label>

                  <div class="mb-2 flex gap-2">
                    <label class="input input-bordered input-sm flex items-center gap-2 flex-1">
                      <.icon name="hero-magnifying-glass" class="w-4 h-4 opacity-70" />
                      <input
                        type="text"
                        phx-debounce="300"
                        name="search"
                        value={@zip_search_term}
                        placeholder="Search (2+ chars)..."
                        class="grow font-mono"
                        autocomplete="off"
                      />
                    </label>
                    <select
                      name="limit"
                      phx-change="change_zip_limit"
                      class="select select-bordered select-sm w-28"
                    >
                      <option value="1000" selected={@zip_search_limit == 1000}>1,000</option>
                      <option value="5000" selected={@zip_search_limit == 5000}>5,000</option>
                      <option value="10000" selected={@zip_search_limit == 10000}>10,000</option>
                      <option value="all" selected={@zip_search_limit == :all}>All</option>
                    </select>
                  </div>

                  <select
                    id="available-zips"
                    multiple
                    size="15"
                    class="select select-bordered w-full h-80 text-sm font-mono [&::-webkit-scrollbar-button]:[display:none]"
                  >
                    <%= for zip <- @zip_search_results do %>
                      <% is_selected = Enum.any?(@selected_zips, &(&1.id == zip.id)) %>
                      <option
                        value={zip.id}
                        disabled={is_selected}
                        class={is_selected && "!text-base-content/40"}
                      >
                        {zip.zip_code} - {zip.location}
                      </option>
                    <% end %>
                  </select>
                </div>

                <div class="flex flex-col items-center justify-center gap-2">
                  <button type="button" data-action="add-all" class="btn btn-sm btn-primary">
                    >>
                  </button>
                  <button type="button" data-action="add-selected" class="btn btn-sm btn-primary">
                    >
                  </button>
                  <button type="button" data-action="remove-selected" class="btn btn-sm btn-secondary">
                    &lt;
                  </button>
                  <button type="button" data-action="clear-all" class="btn btn-sm btn-secondary">
                    &lt;&lt;
                  </button>
                </div>

                <div class="flex-1 min-w-0">
                  <label class="label">
                    <span class="label-text font-semibold">
                      Selected Zip Codes ({length(@selected_zips)})
                    </span>
                  </label>

                  <select
                    id="selected-zips"
                    multiple
                    size="15"
                    class="select select-bordered w-full h-80 text-sm mt-7 font-mono [&::-webkit-scrollbar-button]:[display:none]"
                  >
                    <option :for={zip <- @selected_zips} value={zip.id}>
                      {zip.zip_code} - {zip.location}
                    </option>
                  </select>
                </div>
              </div>
            <% else %>
              <div class="divider">Select Traits</div>

              <div :if={@parent_trait.child_traits} class="py-0">
                <label
                  :for={child_trait <- Enum.sort_by(@parent_trait.child_traits, & &1.display_order)}
                  class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 dark:border-base-content/15 py-4 px-2 hover:bg-base-200/70 dark:hover:bg-base-300/35 cursor-pointer"
                >
                  <input
                    :if={@parent_trait.input_type == "single_select"}
                    type="radio"
                    name="trait_ids[]"
                    value={child_trait.id}
                    id={"trait-#{child_trait.id}"}
                    checked={child_trait.id in @selected_ids}
                    class="radio w-7 h-7"
                  />
                  <input
                    :if={@parent_trait.input_type != "single_select"}
                    type="checkbox"
                    name="trait_ids[]"
                    value={child_trait.id}
                    id={"trait-#{child_trait.id}"}
                    checked={child_trait.id in @selected_ids}
                    class="checkbox w-7 h-7"
                  />
                  <div class="text-lg text-base-content">
                    {if child_trait.survey_answer &&
                          child_trait.survey_answer.text not in [nil, ""],
                        do: child_trait.survey_answer.text,
                        else: child_trait.trait_name}
                  </div>
                </label>
              </div>
            <% end %>
          </div>

          <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
            <button type="button" phx-click="close_modal" class="btn btn-lg btn-ghost">
              Cancel
            </button>
            <button
              type="submit"
              class="btn btn-lg btn-primary"
              disabled={@parent_trait.input_type == "single_select_zip" && @selected_zips == []}
            >
              {@submit_label}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :parents, :list, required: true
  attr :tagged_by_parent, :map, default: %{}

  def tag_starter_cards(assigns) do
    ~H"""
    <div class="space-y-3">
      <h3 class="font-semibold text-base-content">{@title}</h3>
      <ul class="divide-y divide-base-300/60 dark:divide-base-content/10">
        <li
          :for={parent <- @parents}
          id={"starter-trait-#{parent.id}"}
          class="relative flex items-stretch gap-3 px-4 py-3 cursor-pointer transition-colors duration-200 hover:bg-base-200/40 dark:hover:bg-base-300/20"
          phx-click="tag_parent"
          phx-value-id={parent.id}
        >
          <div class="w-[34%] max-w-[9rem] shrink-0 flex items-start pt-2.5">
            <span class={[
              "text-base font-bold leading-tight",
              Map.get(@tagged_by_parent, parent.id, []) == [] &&
                "text-base-content/65 dark:text-base-content/75",
              Map.get(@tagged_by_parent, parent.id, []) != [] && "text-base-content"
            ]}>
              {parent.trait_name}
            </span>
          </div>
          <div
            class={[
              "flex flex-1 min-w-0 items-stretch rounded-lg overflow-hidden",
              "bg-base-200 dark:bg-base-300/55",
              Map.get(@tagged_by_parent, parent.id, []) == [] && "empty-trait-header-strobe"
            ]}
            style={
              Map.get(@tagged_by_parent, parent.id, []) == [] &&
                "--animation-delay: #{rem(abs(parent.id), 2000)}ms"
            }
          >
            <div class="w-1 shrink-0 bg-youdata-500" aria-hidden="true"></div>
            <div class="flex flex-1 min-w-0 items-center justify-between gap-2 px-3 py-2.5">
              <div class="min-w-0 flex-1">
                <ul :if={Map.get(@tagged_by_parent, parent.id, []) != []} class="space-y-0.5">
                  <li
                    :for={name <- Map.get(@tagged_by_parent, parent.id, [])}
                    class="text-sm leading-snug text-base-content/85"
                  >
                    {name}
                  </li>
                </ul>
                <p
                  :if={Map.get(@tagged_by_parent, parent.id, []) == []}
                  class="text-sm leading-snug italic text-base-content/45"
                >
                  Add a tag
                </p>
              </div>
              <.icon name="hero-chevron-right" class="w-5 h-5 shrink-0 text-base-content/40" />
            </div>
          </div>
        </li>
      </ul>
    </div>
    """
  end
end
