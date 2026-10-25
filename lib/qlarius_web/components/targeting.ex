defmodule QlariusWeb.Components.Targeting do
  use QlariusWeb, :html

  import QlariusWeb.Components.MarketerUI, only: [panel: 1, empty_state: 1, chip: 1]

  alias Qlarius.Sponster.Campaigns.{AudienceBuilder, TargetBand, Targets, TraitGroup}
  alias Qlarius.YouData.TraitSearch

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
      depopulate: "Depopulate",
      people: "people",
      done_empty: "Create at least a bullseye before finishing"
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
      depopulate: "Depopulate",
      people: "viewers",
      done_empty: "Add at least one tag or trait group before finishing"
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

  @doc """
  Zip codes a group already holds under other zip topics, offered as a starting
  point when a second zip topic (Work after Home) is added. Nil when there are
  none.
  """
  def zip_seed(group, new_parent_id) do
    zips =
      group.traits
      |> Enum.filter(
        &(&1.input_type == "single_select_zip" and &1.parent_trait_id != new_parent_id)
      )

    case zips do
      [] ->
        nil

      [first | _] ->
        %{
          label: (first.parent_trait && first.parent_trait.trait_name) || "the other zip topic",
          codes: zips |> Enum.map(& &1.trait_name) |> Enum.uniq()
        }
    end
  end

  @doc """
  Human wording for the reasons `AudienceBuilder.set_topic/4` and
  `remove_topic/2` refuse an edit.
  """
  def topic_error(reason, copy) do
    case reason do
      {:frozen_target, _ids} ->
        "This group is on a #{copy.noun_lower} in a live campaign. Depopulate that #{copy.noun_lower} to edit it."

      :frozen_target ->
        "This #{copy.noun_lower} is in a live campaign. Depopulate it to edit."

      :include_group_required ->
        "A band needs a group that includes people before an Anti-Trait Group can remove any."

      {:trait_in_both_roles, _} ->
        "One of those answers is already included by this #{copy.noun_lower}."

      :trait_group_already_in_target ->
        "That group is already on this #{copy.noun_lower}."

      :no_bands_exist ->
        "Create a bullseye first."

      :trait_group_shared ->
        "This group is used by more than one #{copy.noun_lower}. Create a new group instead."

      :last_topic ->
        "A group keeps at least one topic. Delete the group instead."

      :traits_required ->
        "Select at least one answer."

      {:traits_not_children, _} ->
        "Those answers belong to a different topic."

      {:traits_not_found, _} ->
        "Some of those answers are no longer available."

      %Ecto.Changeset{} = changeset ->
        changeset

      other ->
        "Could not save: #{inspect(other)}"
    end
  end

  def excluded_trait_group_id(band, bands) do
    sorted_bands = Enum.sort_by(bands, &Targets.restrictiveness/1, :desc)
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

  defp band_chips(band, bands) do
    dropped_id = excluded_trait_group_id(band, bands)
    {kept, dropped} = Enum.split_with(band.trait_groups, &(&1.id != dropped_id))

    Enum.map(kept, &{&1, false}) ++ Enum.map(dropped, &{&1, true})
  end

  attr :copy, :map, required: true
  attr :bands, :list, required: true
  attr :outermost_band, :any, required: true
  attr :available_trait_groups, :list, required: true
  attr :expanding_target, :boolean, default: false
  attr :show_populate?, :boolean, default: true
  attr :phx_target, :any, default: nil, doc: "LiveComponent that owns the band events"

  attr :me_file_counts, :map,
    default: nil,
    doc: "trait group id => MeFile count; counts are hidden when nil"

  slot :notes, doc: "quiet content under the band list, such as suggestions"

  def band_editor(assigns) do
    ~H"""
    <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_340px]">
      <.panel
        flush
        title="Rings"
        description="The bullseye is your most precise audience. Each outer ring drops one trait group to reach more people."
      >
        <:actions>
          <button type="button" phx-click="done" phx-target={@phx_target} class="btn btn-sm btn-ghost">
            Done
          </button>
          <button
            :if={@show_populate? and @bands != []}
            type="button"
            phx-click="populate_target"
            phx-target={@phx_target}
            class="btn btn-sm btn-primary"
            data-confirm={@copy.populate_confirm}
          >
            {@copy.populate}
          </button>
        </:actions>

        <.empty_state :if={@bands == []} icon="hero-viewfinder-circle" title="No bullseye yet">
          {@copy.empty_hint}
        </.empty_state>

        <ul :if={@bands != []} class="divide-y divide-base-300">
          <li :for={band <- @bands} class="flex items-start gap-4 px-6 py-4">
            <div class="flex w-28 shrink-0 items-center gap-2 pt-1">
              <span class={[
                "size-2 rounded-full",
                if(TargetBand.is_bullseye?(band), do: "bg-error", else: "bg-base-content/30")
              ]} />
              <span class="text-sm font-semibold">{Targets.band_label(band, @bands)}</span>
              <button
                :if={
                  @outermost_band && band.id == @outermost_band.id &&
                    !TargetBand.is_bullseye?(@outermost_band)
                }
                type="button"
                phx-click="delete_outermost_band"
                phx-target={@phx_target}
                class="btn btn-ghost btn-xs btn-square text-error"
                title="Delete this ring"
                aria-label="Delete this ring"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>

            <div class="flex min-w-0 flex-1 flex-wrap gap-2">
              <%= cond do %>
                <% @expanding_target && @outermost_band && band.id == @outermost_band.id &&
                    length(band.trait_groups) > 1 -> %>
                  <button
                    :for={tg <- band.trait_groups}
                    type="button"
                    phx-click="create_outer_band"
                    phx-target={@phx_target}
                    phx-value-excluded_trait_group_id={tg.id}
                    class={[
                      "inline-flex items-center gap-1.5 rounded-md border border-warning/40 bg-warning/10 px-2.5 py-1 text-sm transition-colors hover:border-warning hover:bg-warning/20",
                      tg.id == excluded_trait_group_id(band, @bands) && "opacity-60"
                    ]}
                    title={"Exclude #{tg.title} from the new ring"}
                  >
                    <.role_badge group={tg} /> {tg.title}
                    <.me_file_count counts={@me_file_counts} id={tg.id} role={tg.role} />
                    <.icon name="hero-scissors" class="size-4 text-warning" />
                  </button>
                <% TargetBand.is_bullseye?(band) && length(@bands) == 1 -> %>
                  <span
                    :for={tg <- band.trait_groups}
                    class={[
                      "inline-flex items-center gap-1.5 rounded-md border py-1 pr-1 pl-2.5 text-sm",
                      chip_role_class(tg)
                    ]}
                  >
                    <.role_badge group={tg} /> {tg.title}
                    <.me_file_count counts={@me_file_counts} id={tg.id} role={tg.role} />
                    <button
                      type="button"
                      phx-click="remove_trait_group_from_bullseye"
                      phx-target={@phx_target}
                      phx-value-band_id={band.id}
                      phx-value-trait_group_id={tg.id}
                      class="rounded p-0.5 text-base-content/50 hover:bg-base-300 hover:text-error"
                      title="Remove from bullseye"
                      aria-label={"Remove #{tg.title} from bullseye"}
                    >
                      <.icon name="hero-x-mark" class="size-4" />
                    </button>
                  </span>
                <% true -> %>
                  <span
                    :for={{tg, dropped?} <- band_chips(band, @bands)}
                    class={[
                      "inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1 text-sm",
                      chip_role_class(tg),
                      dropped? && "text-base-content/70"
                    ]}
                    title={dropped? && "Dropped in the next ring"}
                  >
                    <.role_badge group={tg} /> {tg.title}
                    <.me_file_count counts={@me_file_counts} id={tg.id} role={tg.role} />
                    <.icon
                      :if={dropped?}
                      name="hero-arrow-down-right"
                      class="size-3 text-base-content/40"
                    />
                  </span>
              <% end %>
            </div>
          </li>

          <li :if={@expanding_target} class="flex items-start gap-4 bg-warning/5 px-6 py-4">
            <div class="flex w-28 shrink-0 items-center gap-2 pt-1">
              <span class="size-2 rounded-full bg-warning" />
              <span class="text-sm font-semibold">Ring {length(@bands)}</span>
              <button
                type="button"
                phx-click="cancel_expanding_target"
                phx-target={@phx_target}
                class="btn btn-ghost btn-xs btn-square"
                title="Cancel"
                aria-label="Cancel new ring"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <p class="pt-1 text-sm text-base-content/60">
              Pick a trait group in the ring above to leave out of this new ring.
            </p>
          </li>
        </ul>

        <div :if={@notes != [] and @bands != []} class="border-t border-base-300 px-6 py-3">
          {render_slot(@notes)}
        </div>

        <:footer :if={
          @bands != [] && @outermost_band && length(@outermost_band.trait_groups) > 1 &&
            !@expanding_target
        }>
          <button
            type="button"
            phx-click="start_expanding_target"
            phx-target={@phx_target}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-plus" class="size-4" /> {@copy.expand}
          </button>
        </:footer>
      </.panel>

      <.panel title="Trait groups" description={@copy.picker_heading} class="lg:sticky lg:top-22">
        <div
          :if={length(@bands) > 1}
          class="flex items-start gap-3 rounded-xl border border-base-300 bg-base-200/60 p-3"
        >
          <.icon name="hero-lock-closed" class="mt-0.5 size-4 shrink-0 text-base-content/60" />
          <div class="text-sm">
            <p class="font-semibold">Bullseye locked</p>
            <p class="text-xs text-base-content/60">
              Delete the outer rings first to change the bullseye.
            </p>
          </div>
        </div>

        <p :if={@available_trait_groups == []} class="text-sm text-base-content/60">
          {@copy.none_available}
        </p>

        <div :if={@available_trait_groups != []} class="space-y-1.5">
          <button
            :for={tg <- @available_trait_groups}
            type="button"
            phx-click="add_trait_group"
            phx-target={@phx_target}
            phx-value-trait_group_id={tg.id}
            disabled={length(@bands) > 1}
            class="group flex w-full items-center justify-between gap-2 rounded-lg border border-base-300 px-3 py-2 text-left text-sm transition-colors enabled:hover:border-base-content/30 enabled:hover:bg-base-200/60 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <span class="flex min-w-0 items-center gap-1.5">
              <.role_badge group={tg} />
              <span class="truncate">{tg.title}</span>
            </span>
            <span class="flex shrink-0 items-center gap-2">
              <.me_file_count counts={@me_file_counts} id={tg.id} role={tg.role} />
              <.icon
                name="hero-plus"
                class="size-4 text-base-content/40 group-enabled:group-hover:text-base-content"
              />
            </span>
          </button>
        </div>
      </.panel>
    </div>
    """
  end

  attr :counts, :map, default: nil
  attr :id, :integer, required: true
  attr :role, :string, default: "include"

  defp me_file_count(%{counts: nil} = assigns), do: ~H""

  defp me_file_count(assigns) do
    assigns = assign(assigns, :count, Map.get(assigns.counts, assigns.id, 0))

    ~H"""
    <span
      class="inline-flex items-center gap-0.5 text-xs text-base-content/50"
      title={"#{@count} MeFiles#{if @role == "anti", do: " removed"}"}
    >
      <.icon name={if @role == "anti", do: "hero-user-minus", else: "hero-user"} class="size-3" />{@count}
    </span>
    """
  end

  attr :group, :map, required: true
  attr :class, :string, default: nil

  @doc """
  Marks an Anti-Trait Group wherever a group is named. Include groups show nothing.
  """
  def role_badge(assigns) do
    ~H"""
    <span
      :if={TraitGroup.anti?(@group)}
      class={["mr-1 inline-flex shrink-0 items-center text-error", @class]}
      title="Anti-Trait Group: removes anyone with these answers"
      aria-label="keep out"
    >
      <.icon name="hero-no-symbol" class="size-3.5" />
    </span>
    """
  end

  attr :groups, :list, required: true, doc: "every active group, to decide whether to show"
  attr :value, :string, required: true, doc: "\"all\", \"include\", or \"anti\""

  @doc """
  A small role filter for group lists. Appears once a workspace has an
  Anti-Trait Group; pages handle `filter_role` with a `role` value.
  """
  def role_filter(assigns) do
    ~H"""
    <div
      :if={Enum.any?(@groups, &TraitGroup.anti?/1)}
      class="join"
      role="group"
      aria-label="Filter by role"
    >
      <button
        :for={{value, label} <- [{"all", "All"}, {"include", "Include"}, {"anti", "Keep out"}]}
        type="button"
        phx-click="filter_role"
        phx-value-role={value}
        class={["btn btn-xs join-item", @value == value && "btn-active"]}
        aria-pressed={to_string(@value == value)}
      >
        {label}
      </button>
    </div>
    """
  end

  @doc """
  Groups matching a `role_filter` value.
  """
  def filter_by_role(groups, "all"), do: groups
  def filter_by_role(groups, role), do: Enum.filter(groups, &(&1.role == role))

  defp chip_role_class(group) do
    if TraitGroup.anti?(group),
      do: "border-error/40 bg-error/5",
      else: "border-base-300 bg-base-200"
  end

  attr :copy, :map, required: true
  attr :bands, :list, required: true
  attr :band_population_counts, :map, required: true
  attr :show_frozen_note?, :boolean, default: true

  def population_inspect(assigns) do
    total = assigns.band_population_counts |> Map.values() |> Enum.sum()
    assigns = assign(assigns, :total_population, total)

    ~H"""
    <div class="space-y-6">
      <.panel flush title="Population" description="How many people fall into each ring.">
        <:actions>
          <button type="button" phx-click="done" class="btn btn-sm btn-ghost">Done</button>
          <button
            type="button"
            phx-click="depopulate_target"
            class="btn btn-sm btn-ghost text-error"
            data-confirm="This will delete all population data. Continue?"
          >
            {@copy.depopulate}
          </button>
          <button
            type="button"
            phx-click="refresh_population"
            class="btn btn-sm btn-primary"
            data-confirm="This will recalculate populations for all rings. Continue?"
          >
            <.icon name="hero-arrow-path" class="size-4" /> {@copy.refresh}
          </button>
        </:actions>

        <ul class="divide-y divide-base-300">
          <li :for={band <- @bands} class="flex items-start gap-4 px-6 py-4">
            <div class="flex w-28 shrink-0 items-center gap-2 pt-1">
              <span class={[
                "size-2 rounded-full",
                if(TargetBand.is_bullseye?(band), do: "bg-error", else: "bg-base-content/30")
              ]} />
              <span class="text-sm font-semibold">{Targets.band_label(band, @bands)}</span>
            </div>
            <div class="flex min-w-0 flex-1 flex-wrap gap-2">
              <span
                :for={{tg, dropped?} <- band_chips(band, @bands)}
                class={[
                  "inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1 text-sm",
                  chip_role_class(tg),
                  dropped? && "text-base-content/70"
                ]}
                title={dropped? && "Dropped in the next ring"}
              >
                <.role_badge group={tg} />
                {tg.title}
                <.icon
                  :if={dropped?}
                  name="hero-arrow-down-right"
                  class="size-3 text-base-content/40"
                />
              </span>
            </div>
            <div class="shrink-0 pt-1 text-right">
              <span class="text-lg font-semibold">
                {Map.get(@band_population_counts, band.id, 0)}
              </span>
              <span class="text-xs text-base-content/50">people</span>
            </div>
          </li>
        </ul>

        <:footer>
          <span class="mr-auto text-sm font-semibold">Total population</span>
          <span class="text-lg font-semibold">{@total_population}</span>
        </:footer>
      </.panel>

      <div
        :if={@show_frozen_note?}
        class="flex items-start gap-3 rounded-xl border border-base-300 bg-base-200/60 p-4"
      >
        <.icon name="hero-lock-closed" class="mt-0.5 size-4 shrink-0 text-base-content/60" />
        <div class="text-sm">
          <p class="font-semibold">{@copy.locked_title}</p>
          <p class="text-xs text-base-content/60">{@copy.locked_body}</p>
        </div>
      </div>
    </div>
    """
  end

  @topic_chip_limit 12

  attr :trait_groups, :list, required: true
  attr :archived, :boolean, default: false
  attr :usage_label, :string, default: "In targets"
  attr :deactivate_confirm, :string, default: "Deactivate this trait group? It is in use."
  attr :topic_path, :any, required: true, doc: "fn group, parent_trait_id -> patch path"

  def trait_group_list(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300">
      <li
        :for={group <- @trait_groups}
        id={"trait-group-#{group.id}"}
        class={[
          "flex items-start gap-5 px-6 py-4 transition-colors hover:bg-base-200/40",
          @archived && "opacity-70"
        ]}
      >
        <div class="min-w-0 flex-1">
          <p class="flex items-center gap-2 font-semibold">
            {group.title} <.role_badge group={group} />
          </p>
          <p :if={group.description} class="text-sm text-base-content/60">{group.description}</p>
          <.topic_rows group={group} archived={@archived} topic_path={@topic_path} />
        </div>

        <dl class="grid shrink-0 grid-cols-2 gap-6 text-right max-sm:hidden">
          <div>
            <dt class="text-xs text-base-content/50">
              {if TraitGroup.anti?(group), do: "MeFiles removed", else: "MeFiles"}
            </dt>
            <dd class="font-semibold">{group.me_file_count}</dd>
          </div>
          <div>
            <dt class="text-xs text-base-content/50">{@usage_label}</dt>
            <dd class="font-semibold">{group.target_band_count}</dd>
          </div>
        </dl>

        <div class="shrink-0">
          <%= cond do %>
            <% @archived -> %>
              <button
                type="button"
                phx-click="reactivate_trait_group"
                phx-value-id={group.id}
                class="btn btn-sm btn-ghost"
              >
                <.icon name="hero-arrow-uturn-left" class="size-4" /> Reactivate
              </button>
            <% group.target_band_count > 0 -> %>
              <button
                type="button"
                phx-click="deactivate_trait_group"
                phx-value-id={group.id}
                class="btn btn-sm btn-ghost"
                data-confirm={@deactivate_confirm}
              >
                <.icon name="hero-archive-box" class="size-4" /> Deactivate
              </button>
            <% true -> %>
              <button
                type="button"
                phx-click="delete_trait_group"
                phx-value-id={group.id}
                class="btn btn-sm btn-ghost btn-square text-error"
                title="Delete"
                aria-label={"Delete #{group.title}"}
                data-confirm="Delete this trait group? This cannot be undone."
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
          <% end %>
        </div>
      </li>
    </ul>
    """
  end

  attr :group, :map, required: true
  attr :archived, :boolean, default: false
  attr :topic_path, :any, required: true

  defp topic_rows(assigns) do
    topics = AudienceBuilder.topics(assigns.group)

    assigns =
      assigns
      |> assign(:topics, topics)
      |> assign(:multi?, length(topics) > 1)
      |> assign(:chip_limit, @topic_chip_limit)

    ~H"""
    <div class="mt-2 space-y-2">
      <p :if={@multi? or TraitGroup.anti?(@group)} class="text-xs text-base-content/60">
        {topic_sentence(@group, @multi?)}
      </p>
      <div
        :for={%{parent: parent, traits: traits} <- @topics}
        id={"trait-group-#{@group.id}-topic-#{(parent && parent.id) || "none"}"}
        class="flex items-start gap-3"
      >
        <div class="min-w-0 flex-1 space-y-1">
          <div :if={parent} class="text-xs font-medium text-base-content/60">
            {parent.trait_name}
          </div>
          <div class="flex flex-wrap gap-1">
            <.chip :for={trait <- Enum.take(traits, @chip_limit)}>{trait.trait_name}</.chip>
            <.chip :if={length(traits) > @chip_limit} class="border-dashed bg-transparent">
              +{length(traits) - @chip_limit} more
            </.chip>
          </div>
        </div>
        <div :if={not @archived and parent} class="flex shrink-0 items-center gap-1">
          <.link
            patch={@topic_path.(@group, parent.id)}
            class="btn btn-ghost btn-xs"
            aria-label={"Edit #{parent.trait_name} in #{@group.title}"}
          >
            Edit
          </.link>
          <button
            :if={@multi?}
            type="button"
            phx-click="remove_topic"
            phx-value-group_id={@group.id}
            phx-value-parent_trait_id={parent.id}
            data-confirm={"Remove #{parent.trait_name} from #{@group.title}?"}
            class="btn btn-ghost btn-xs btn-square"
            title="Remove topic"
            aria-label={"Remove #{parent.trait_name} from #{@group.title}"}
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </div>
      <button
        :if={not @archived}
        type="button"
        phx-click="add_topic"
        phx-value-group_id={@group.id}
        class="btn btn-ghost btn-xs text-base-content/70"
      >
        <.icon name="hero-plus" class="size-3.5" /> Add topic
      </button>
    </div>
    """
  end

  defp topic_sentence(group, multi?) do
    case {TraitGroup.anti?(group), multi?} do
      {true, true} -> "Removes anyone with any of these answers."
      {true, false} -> "Removes anyone with one of these answers."
      {false, _} -> "Matches anyone with any of these answers."
    end
  end

  attr :categories, :list, required: true
  attr :search_term, :string, required: true
  attr :trait_match_ids, :any, required: true
  attr :topic_path, :any, required: true, doc: "fn parent_trait_id -> path"
  attr :adding_to, :map, default: nil, doc: "group receiving a new topic, or nil"

  def trait_browser(assigns) do
    assigns =
      assign(
        assigns,
        :filtered,
        TraitSearch.filter_categories(assigns.categories, assigns.trait_match_ids)
      )

    ~H"""
    <.panel
      title="Trait browser"
      description={
        if @adding_to,
          do: "Pick the topic to add to this group.",
          else: "Choose a trait to group its answers."
      }
      class="lg:sticky lg:top-22"
    >
      <div
        :if={@adding_to}
        id="adding-topic-banner"
        class="mb-3 flex items-center justify-between gap-2 rounded-lg border border-primary/40 bg-primary/5 px-3 py-2 text-sm"
      >
        <span class="min-w-0 truncate">
          Adding a topic to <span class="font-semibold">{@adding_to.title}</span>
        </span>
        <button type="button" phx-click="cancel_add_topic" class="btn btn-ghost btn-xs">
          Cancel
        </button>
      </div>

      <form phx-change="search_traits" phx-submit="search_traits">
        <label class="input input-bordered flex w-full items-center gap-2">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="text"
            phx-debounce="300"
            name="search"
            value={@search_term}
            placeholder="Search traits"
            class="grow"
            autocomplete="off"
          />
          <button
            :if={@search_term != ""}
            type="button"
            phx-click="clear_search"
            class="btn btn-ghost btn-xs btn-circle"
            aria-label="Clear search"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </label>
      </form>

      <p
        :if={match?(%MapSet{}, @trait_match_ids) and @filtered == []}
        class="py-6 text-center text-sm text-base-content/60"
      >
        No traits match "{@search_term}".
      </p>

      <div class="-mx-2 max-h-[calc(100vh-20rem)] space-y-1 overflow-y-auto">
        <details :for={category <- @filtered} open class="group/category">
          <summary class="flex cursor-pointer list-none items-center justify-between rounded-lg px-2 py-2 text-sm font-semibold hover:bg-base-200/60">
            <span class="flex items-center gap-1.5">
              <.icon
                name="hero-chevron-right"
                class="size-4 text-base-content/40 transition-transform group-open/category:rotate-90"
              />
              {category.name}
            </span>
            <span class="text-xs font-normal text-base-content/50">{length(category.traits)}</span>
          </summary>
          <div class="pb-2 pl-5">
            <.link
              :for={trait <- category.traits}
              patch={@topic_path.(trait.id)}
              class="group flex items-center justify-between rounded-lg px-2 py-1.5 text-sm text-base-content/80 hover:bg-base-200/60 hover:text-base-content"
            >
              <span class="min-w-0 truncate">{trait.trait_name}</span>
              <.icon
                name="hero-plus"
                class="size-4 shrink-0 text-base-content/30 group-hover:text-base-content"
              />
            </.link>
          </div>
        </details>
      </div>
    </.panel>
    """
  end

  attr :suggestions, :map, required: true, doc: "AntiGroupSuggestions.for_target/1"
  attr :count, :integer, required: true
  attr :copy, :map, required: true
  attr :phx_target, :any, default: nil

  @doc """
  One quiet line under the rings. Says nothing when there is nothing to suggest
  and nothing was dismissed. Never marks the target wrong.
  """
  def anti_suggestion_line(assigns) do
    ~H"""
    <p
      :if={@count > 0}
      id="anti-suggestion-line"
      class="flex items-center gap-2 text-sm text-base-content/70"
    >
      <.icon name="hero-light-bulb" class="size-4 shrink-0 text-base-content/50" />
      <span>
        {@count} {if @count == 1, do: "answer", else: "answers"} you may want to keep out of this {@copy.noun_lower}.
      </span>
      <button
        type="button"
        phx-click="open_suggestions"
        phx-target={@phx_target}
        class="link link-hover font-medium"
      >
        Review
      </button>
    </p>
    <p :if={@count == 0 and @suggestions.dismissed != []} class="text-xs text-base-content/50">
      <button
        type="button"
        phx-click="open_suggestions"
        phx-target={@phx_target}
        class="link link-hover"
      >
        Suggestions
      </button>
    </p>
    """
  end

  attr :suggestions, :map, required: true
  attr :review, :map, required: true, doc: "selected ids, titles, shape, band_ids, combined_title"
  attr :bands, :list, required: true
  attr :copy, :map, required: true
  attr :error, :string, default: nil
  attr :phx_target, :any, default: nil

  @doc """
  The review drawer for Anti-Trait Group suggestions: pick answers per topic,
  name the group or groups, choose one combined group or one per topic, and
  confirm. Each topic can be dismissed for this target; dismissed topics stay
  reachable at the bottom.
  """
  def suggestion_review(assigns) do
    topics = assigns.suggestions.topics
    selected = assigns.review.selected

    assigns =
      assigns
      |> assign(:topics, topics)
      |> assign(:selected_count, MapSet.size(selected))
      |> assign(:multi_topic?, length(topics) > 1)
      |> assign(:multi_band?, length(assigns.bands) > 1)

    ~H"""
    <div class="modal modal-bottom md:modal-middle modal-open bg-base-300/80 backdrop-blur-sm">
      <div class="modal-box flex max-h-[90vh] flex-col border border-base-300 bg-base-100 p-0 !max-w-2xl">
        <div class="flex shrink-0 items-baseline justify-between bg-base-200 p-4">
          <div>
            <h3 class="text-lg font-bold">Keep out</h3>
            <p class="text-sm text-base-content/60">
              Answers that marketers targeting what this {@copy.noun_lower} includes tend to keep out. Your call.
            </p>
          </div>
          <button
            type="button"
            phx-click="close_suggestions"
            phx-target={@phx_target}
            class="btn btn-md btn-circle btn-ghost"
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        <div :if={@suggestions.frozen?} class="shrink-0 bg-warning/10 px-4 py-2 text-sm">
          This {@copy.noun_lower} is in a live campaign. Depopulate it to edit.
        </div>

        <form
          id="suggestion-review-form"
          phx-change="review_change"
          phx-submit="confirm_suggestions"
          phx-target={@phx_target}
          class="flex min-h-0 flex-1 flex-col"
        >
          <div class="flex-1 space-y-5 overflow-y-auto p-4">
            <p :if={@topics == []} class="text-sm text-base-content/60">
              Nothing open right now.
            </p>

            <section
              :for={%{parent: parent, traits: traits} <- @topics}
              id={"suggestion-topic-#{parent.id}"}
              class="rounded-xl border border-base-300"
            >
              <div class="flex items-center justify-between gap-2 border-b border-base-300 px-3 py-2">
                <span class="font-semibold">{parent.trait_name}</span>
                <span class="flex items-center gap-1 text-xs">
                  <button
                    type="button"
                    phx-click="select_topic"
                    phx-value-parent_trait_id={parent.id}
                    phx-target={@phx_target}
                    class="btn btn-ghost btn-xs"
                  >
                    Select all
                  </button>
                  <button
                    type="button"
                    phx-click="clear_topic"
                    phx-value-parent_trait_id={parent.id}
                    phx-target={@phx_target}
                    class="btn btn-ghost btn-xs"
                  >
                    Clear
                  </button>
                  <button
                    type="button"
                    phx-click="dismiss_topic"
                    phx-value-parent_trait_id={parent.id}
                    phx-target={@phx_target}
                    class="btn btn-ghost btn-xs text-base-content/60"
                    title="Hide this topic for this target"
                  >
                    Not for this {@copy.noun_lower}
                  </button>
                </span>
              </div>

              <label
                :for={%{trait: trait, severity: severity, because: because, note: note} <- traits}
                class="flex cursor-pointer items-start gap-3 border-b border-dashed border-base-300 px-3 py-2 last:border-b-0 hover:bg-base-200/60"
              >
                <input
                  type="checkbox"
                  name="trait_ids[]"
                  value={trait.id}
                  checked={MapSet.member?(@review.selected, trait.id)}
                  class="checkbox checkbox-sm mt-0.5"
                />
                <span class="min-w-0 flex-1">
                  <span class="flex items-center gap-2">
                    <span>{trait.trait_name}</span>
                    <span class={[
                      "badge badge-xs",
                      if(severity == "hard", do: "badge-neutral", else: "badge-ghost")
                    ]}>
                      {if severity == "hard", do: "will not want", else: "may not want"}
                    </span>
                  </span>
                  <span class="block text-xs text-base-content/60">
                    Because you include {Enum.join(because, ", ")}{if note, do: " · #{note}"}
                  </span>
                </span>
              </label>

              <div :if={not @multi_topic? or @review.shape == "per_topic"} class="px-3 py-2">
                <input
                  type="text"
                  name={"titles[#{parent.id}]"}
                  value={Map.get(@review.titles, parent.id, "")}
                  placeholder={"Keep out · #{parent.trait_name}"}
                  class="input input-sm w-full"
                  aria-label={"Group name for #{parent.trait_name}"}
                />
              </div>
            </section>

            <fieldset :if={@multi_topic?} class="space-y-2 text-sm">
              <legend class="text-xs font-medium text-base-content/60">Shape</legend>
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name="shape"
                  value="combined"
                  checked={@review.shape == "combined"}
                  class="radio radio-sm"
                /> One Anti-Trait Group with every chosen answer
              </label>
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  name="shape"
                  value="per_topic"
                  checked={@review.shape == "per_topic"}
                  class="radio radio-sm"
                /> One Anti-Trait Group per topic, so rings can drop them separately
              </label>
              <input
                :if={@review.shape == "combined"}
                type="text"
                name="combined_title"
                value={@review.combined_title || ""}
                placeholder={"Keep out · " <> Enum.map_join(@topics, ", ", & &1.parent.trait_name)}
                class="input input-sm w-full"
                aria-label="Group name"
              />
            </fieldset>

            <fieldset :if={@multi_band? and @topics != []} class="space-y-1 text-sm">
              <legend class="text-xs font-medium text-base-content/60">Apply to</legend>
              <label :for={band <- @bands} class="flex items-center gap-2">
                <input
                  type="checkbox"
                  name="band_ids[]"
                  value={band.id}
                  checked={band.id in @review.band_ids}
                  class="checkbox checkbox-sm"
                />
                {Targets.band_label(band, @bands)}
              </label>
            </fieldset>

            <div :if={@suggestions.dismissed != []} class="text-xs text-base-content/60">
              <span class="font-medium">Dismissed for this {@copy.noun_lower}:</span>
              <span
                :for={%{parent: parent} <- @suggestions.dismissed}
                class="ml-1 inline-flex items-center gap-1"
              >
                {parent.trait_name}
                <button
                  type="button"
                  phx-click="reopen_topic"
                  phx-value-parent_trait_id={parent.id}
                  phx-target={@phx_target}
                  class="link link-hover"
                >
                  Reopen
                </button>
              </span>
            </div>
          </div>

          <div class="flex shrink-0 items-center justify-end gap-2 border-t border-base-300 bg-base-200 p-4">
            <p :if={@error} class="mr-auto text-sm text-error">{@error}</p>
            <button
              type="button"
              phx-click="close_suggestions"
              phx-target={@phx_target}
              class="btn btn-ghost"
            >
              Not now
            </button>
            <button
              type="submit"
              class="btn btn-primary"
              disabled={@selected_count == 0 or @suggestions.frozen? or @review.band_ids == []}
            >
              Keep out {@selected_count}
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  @doc """
  Text matched by the tagging search box: title, survey answer, and every meta field.
  """
  def tag_option_search_text(trait) do
    answer =
      case Map.get(trait, :survey_answer) do
        %{text: text} when is_binary(text) -> text
        _ -> nil
      end

    [
      Map.get(trait, :trait_name),
      answer,
      Map.get(trait, :meta_1),
      Map.get(trait, :meta_2),
      Map.get(trait, :meta_3)
    ]
    |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
    |> Enum.map_join(" ", &String.trim/1)
  end

  def tag_option_meta(trait) do
    [Map.get(trait, :meta_1), Map.get(trait, :meta_2), Map.get(trait, :meta_3)]
    |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
    |> Enum.map_join(" · ", &String.trim/1)
  end

  def tag_option_answer(trait) do
    name = trait |> Map.get(:trait_name) |> to_string() |> String.trim()

    case Map.get(trait, :survey_answer) do
      %{text: text} when is_binary(text) ->
        trimmed = String.trim(text)
        if trimmed != "" and trimmed != name, do: trimmed, else: ""

      _ ->
        ""
    end
  end

  def tag_option_detail?(trait) do
    tag_option_meta(trait) != "" or tag_option_answer(trait) != ""
  end

  def tag_list_toggle?(trait) do
    Map.get(trait, :input_type) != "single_select_zip" and
      is_list(Map.get(trait, :child_traits)) and
      Enum.any?(trait.child_traits, &tag_option_detail?/1)
  end

  def tag_option_filter?(trait) do
    Map.get(trait, :has_search_filter) == true and
      Map.get(trait, :input_type) != "single_select_zip"
  end

  attr :id, :string, required: true

  def tag_option_search(assigns) do
    ~H"""
    <div id={@id} phx-update="ignore" class="px-4 pt-4 shrink-0">
      <label class="input input-bordered flex w-full items-center gap-2">
        <.icon name="hero-magnifying-glass" class="h-4 w-4 opacity-50 shrink-0" />
        <input
          type="search"
          data-tag-option-search
          placeholder="Search"
          autocomplete="off"
          aria-label="Search"
          class="grow bg-transparent outline-none"
        />
      </label>
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
  attr :error, :string, default: nil
  attr :phx_target, :any, default: nil, doc: "LiveComponent that owns the modal events"

  attr :zip_seed, :map,
    default: nil,
    doc: "%{label, codes} zip codes from another topic in the group, offered as a start"

  attr :role_choice?, :boolean,
    default: false,
    doc: "offer the Anti-Trait Group toggle; only when creating a new group"

  attr :show_expanded_tags, :boolean, default: false

  def trait_group_modal(assigns) do
    assigns =
      assign(
        assigns,
        :heading,
        assigns.heading || "Create Trait Group: #{assigns.parent_trait.trait_name}"
      )

    ~H"""
    <div class={[
      "modal modal-bottom md:modal-middle",
      @show_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
    ]}>
      <div class={[
        "flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0 max-h-[90vh]",
        @parent_trait.input_type == "single_select_zip" && "!max-w-3xl"
      ]}>
        <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content shrink-0">
          <h3 class="text-lg font-bold">{@heading}</h3>
          <button
            type="button"
            phx-click="close_modal"
            phx-target={@phx_target}
            class="btn btn-md btn-circle btn-ghost"
          >
            ✕
          </button>
        </div>

        <div
          :if={@parent_trait.survey_question}
          class="p-4 bg-base-200 text-base-content/70 shrink-0 text-sm"
        >
          <p>{Phoenix.HTML.raw(@parent_trait.survey_question.text)}</p>
        </div>

        <div
          id={"tag-option-filter-#{@parent_trait.id}"}
          phx-hook={tag_option_filter?(@parent_trait) && "TagOptionFilter"}
          class="flex flex-col flex-1 min-h-0"
        >
          <.tag_option_search
            :if={tag_option_filter?(@parent_trait)}
            id={"tag-option-search-#{@parent_trait.id}"}
          />
          <.form
            for={@form}
            id="trait-group-form"
            phx-change="validate_trait_group"
            phx-submit="save_trait_group"
            phx-target={@phx_target}
            class="flex flex-col flex-1 min-h-0"
          >
            <div class="flex-1 overflow-y-auto p-4 space-y-4">
              <div>
                <.input field={@form[:title]} type="text" label="Trait Group Name" required />
              </div>

              <div>
                <.input field={@form[:description]} type="textarea" label="Description (optional)" />
              </div>

              <label
                :if={@role_choice?}
                class="flex cursor-pointer items-start gap-3 rounded-lg border border-base-300 px-3 py-2 text-sm"
              >
                <input type="hidden" name="trait_group[role]" value="include" />
                <input
                  type="checkbox"
                  name="trait_group[role]"
                  value="anti"
                  checked={@form[:role].value == "anti"}
                  class="checkbox checkbox-sm mt-0.5"
                />
                <span>
                  <span class="font-medium">Create as Anti-Trait Group</span>
                  <span class="block text-xs text-base-content/60">
                    Removes anyone with these answers from a band instead of including them. This cannot change later.
                  </span>
                </span>
              </label>

              <%= if @parent_trait.input_type == "single_select_zip" do %>
                <div class="divider">Select Zip Codes</div>

                <div
                  :if={@zip_seed && @selected_zips == []}
                  class="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-base-300 bg-base-200/60 px-3 py-2 text-sm"
                >
                  <span class="text-base-content/70">
                    This group already holds {length(@zip_seed.codes)} zip codes under {@zip_seed.label}.
                  </span>
                  <button
                    type="button"
                    phx-click="seed_zips"
                    phx-target={@phx_target}
                    class="btn btn-sm btn-ghost"
                  >
                    Start with the same zip codes
                  </button>
                </div>

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
                        phx-target={@phx_target}
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
                    <button
                      type="button"
                      data-action="remove-selected"
                      class="btn btn-sm btn-secondary"
                    >
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

                <.pill_join_selector :if={tag_list_toggle?(@parent_trait)} label="Tag list view">
                  <.pill_join_item
                    active={!@show_expanded_tags}
                    phx-click="set_tag_view"
                    phx-target={@phx_target}
                    phx-value-expanded="false"
                    aria-pressed={to_string(!@show_expanded_tags)}
                  >
                    Simple
                  </.pill_join_item>
                  <.pill_join_item
                    active={@show_expanded_tags}
                    phx-click="set_tag_view"
                    phx-target={@phx_target}
                    phx-value-expanded="true"
                    aria-pressed={to_string(@show_expanded_tags)}
                  >
                    Expanded
                  </.pill_join_item>
                </.pill_join_selector>

                <div :if={@parent_trait.child_traits} class="py-0">
                  <label
                    :for={child_trait <- Enum.sort_by(@parent_trait.child_traits, & &1.display_order)}
                    data-tag-option-row
                    data-tag-option-text={tag_option_search_text(child_trait)}
                    class={[
                      "flex gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 dark:border-base-content/15 py-4 px-2 hover:bg-base-200/70 dark:hover:bg-base-300/35 cursor-pointer",
                      @show_expanded_tags && "items-start",
                      !@show_expanded_tags && "items-center"
                    ]}
                  >
                    <input
                      type="checkbox"
                      name="trait_ids[]"
                      value={child_trait.id}
                      id={"trait-#{child_trait.id}"}
                      checked={child_trait.id in @selected_ids}
                      class={["checkbox w-7 h-7 shrink-0", @show_expanded_tags && "mt-1"]}
                    />
                    <div class="min-w-0 flex-1">
                      <div class="text-lg text-base-content">{child_trait.trait_name}</div>
                      <div
                        :if={@show_expanded_tags && tag_option_answer(child_trait) != ""}
                        class="mt-1 text-sm text-base-content/60 whitespace-normal break-words"
                      >
                        {tag_option_answer(child_trait)}
                      </div>
                      <div
                        :if={@show_expanded_tags && tag_option_meta(child_trait) != ""}
                        class="mt-1 text-sm text-base-content/60 whitespace-normal break-words"
                      >
                        {tag_option_meta(child_trait)}
                      </div>
                    </div>
                  </label>
                </div>
              <% end %>
            </div>

            <div class="p-4 flex flex-row items-center gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
              <p :if={@error} class="mr-auto text-sm text-error">{@error}</p>
              <button
                type="button"
                phx-click="close_modal"
                phx-target={@phx_target}
                class="btn btn-lg btn-ghost"
              >
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
