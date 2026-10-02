defmodule QlariusWeb.Admin.AdCategoryManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Sponster.Ads.{AdCategories, AdCategory}
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar, SearchSelect}

  @empty_filters %{"q" => "", "category_id" => "", "cohort" => "", "active" => ""}
  @new_category "__new__"
  @new_cohort "__new__"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       filters: @empty_filters,
       collapsed: MapSet.new(),
       details: MapSet.new(),
       selected: MapSet.new(),
       remap: nil,
       prune: nil,
       category_edit: nil,
       new_cohort_value: AdCategories.new_cohort()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Ad Categories")
    |> load_rows()
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Ad Categories")
    |> assign(:categories, AdCategories.list_categories())
    |> assign(:cohorts, AdCategories.list_cohorts())
    |> assign(:new_form, to_form(new_defaults(), as: :new))
    |> assign(:new_error, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    row = AdCategories.get_row!(id)

    socket
    |> assign(:page_title, "Edit #{row.row_id}")
    |> assign(:row, row)
    |> assign(:cohorts, AdCategories.list_cohorts())
    |> assign(:form, to_form(AdCategories.change_row(row)))
  end

  defp load_rows(socket) do
    rows = AdCategories.list_rows(socket.assigns.filters)
    categories = AdCategories.list_categories()

    assign(socket,
      rows: rows,
      groups: AdCategories.group_rows(rows),
      categories: categories,
      cohorts: AdCategories.list_cohorts(),
      total_count: categories |> Enum.map(& &1.count) |> Enum.sum()
    )
  end

  defp new_defaults do
    %{
      "category_id" => "",
      "category_name" => "",
      "category_label" => "",
      "labels" => "",
      "cohort" => @new_cohort,
      "age_gated" => "false",
      "age_min" => "",
      "sales_channel_default" => "",
      "meta_1" => "",
      "meta_2" => "",
      "meta_3" => ""
    }
  end

  ## Index events

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    filters = Map.merge(@empty_filters, Map.take(filters, Map.keys(@empty_filters)))
    {:noreply, socket |> assign(filters: filters, selected: MapSet.new()) |> load_rows()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, socket |> assign(filters: @empty_filters) |> load_rows()}
  end

  def handle_event("toggle_category", %{"id" => id}, socket) do
    {:noreply, assign(socket, collapsed: toggle(socket.assigns.collapsed, id))}
  end

  def handle_event("expand_all", _params, socket) do
    {:noreply, assign(socket, collapsed: MapSet.new())}
  end

  def handle_event("collapse_all", _params, socket) do
    {:noreply, assign(socket, collapsed: MapSet.new(socket.assigns.groups, & &1.category_id))}
  end

  def handle_event("toggle_details", %{"id" => id}, socket) do
    {:noreply, assign(socket, details: toggle(socket.assigns.details, String.to_integer(id)))}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected: toggle(socket.assigns.selected, String.to_integer(id)))}
  end

  def handle_event("select_category", %{"id" => category_id}, socket) do
    ids =
      socket.assigns.rows
      |> Enum.filter(&(&1.category_id == category_id))
      |> MapSet.new(& &1.id)

    selected =
      if MapSet.subset?(ids, socket.assigns.selected),
        do: MapSet.difference(socket.assigns.selected, ids),
        else: MapSet.union(socket.assigns.selected, ids)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("bulk_cohort", %{"cohort" => cohort}, socket) do
    cohort = if cohort == @new_cohort, do: socket.assigns.new_cohort_value, else: cohort

    row_ids =
      socket.assigns.rows
      |> Enum.filter(&MapSet.member?(socket.assigns.selected, &1.id))
      |> Enum.map(& &1.row_id)

    case AdCategories.set_cohort(%{"row_ids" => row_ids}, cohort) do
      {:ok, %{updated: count}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Moved #{count} row(s) to cohort #{cohort}")
         |> assign(selected: MapSet.new(), new_cohort_value: AdCategories.new_cohort())
         |> load_rows()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("set_active", %{"id" => id, "active" => active}, socket) do
    row = AdCategories.get_row!(id)

    case AdCategories.update_row(row, %{"active" => active}) do
      {:ok, row} ->
        verb = if row.active, do: "Activated", else: "Deactivated"
        {:noreply, socket |> put_flash(:info, "#{verb} #{row.row_id}") |> load_rows()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    row = AdCategories.get_row!(id)

    case AdCategories.delete_row(row) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Deleted #{row.row_id}") |> load_rows()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("open_remap", %{"id" => id}, socket) do
    row = AdCategories.get_row!(id)

    remap = %{
      row: row,
      count: AdCategories.media_pieces_count(row),
      target: nil,
      options: Enum.reject(AdCategories.picker_options(), &(&1.value == row.id))
    }

    {:noreply, assign(socket, remap: remap)}
  end

  def handle_event("confirm_remap", _params, socket) do
    %{row: row, target: target_id} = socket.assigns.remap
    target = target_id && AdCategories.get_row!(target_id)

    spec = %{
      "mappings" => [%{"from_row_id" => row.row_id, "to_row_id" => target && target.row_id}]
    }

    case target && AdCategories.remap_media_pieces(spec) do
      {:ok, %{moved: moved}} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Moved #{moved} media piece(s) from #{row.row_id} to #{target.row_id}"
         )
         |> assign(remap: nil)
         |> load_rows()}

      nil ->
        {:noreply, put_flash(socket, :error, "Pick a target row first")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("prune_preview", _params, socket) do
    {:ok, preview} = AdCategories.prune_unused(prune_selector(socket), dry_run: true)
    {:noreply, assign(socket, prune: preview)}
  end

  def handle_event("confirm_prune", _params, socket) do
    {:ok, %{count: count}} = AdCategories.prune_unused(prune_selector(socket))

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{count} unused row(s)")
     |> assign(prune: nil)
     |> load_rows()}
  end

  def handle_event("open_category", %{"id" => category_id}, socket) do
    category = Enum.find(socket.assigns.categories, &(&1.category_id == category_id))

    form =
      to_form(
        %{"category_name" => category.category_name, "category_label" => category.category_label},
        as: :category
      )

    {:noreply, assign(socket, category_edit: %{category: category, form: form, error: nil})}
  end

  def handle_event("save_category", %{"category" => attrs}, socket) do
    %{category: category} = socket.assigns.category_edit

    case AdCategories.rename_category(category.category_id, attrs) do
      {:ok, %{updated: count}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Renamed #{category.category_id} on #{count} row(s)")
         |> assign(category_edit: nil)
         |> load_rows()}

      {:error, reason} ->
        edit = %{
          socket.assigns.category_edit
          | form: to_form(attrs, as: :category),
            error: error_text(reason)
        }

        {:noreply, assign(socket, category_edit: edit)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, remap: nil, prune: nil, category_edit: nil)}
  end

  ## New and edit events

  def handle_event("validate_new", %{"new" => params}, socket) do
    {:noreply, assign(socket, new_form: to_form(params, as: :new))}
  end

  def handle_event("save_new", %{"new" => params}, socket) do
    attrs =
      params
      |> Map.take(~w(age_gated age_min sales_channel_default meta_1 meta_2 meta_3))
      |> Map.put("cohort", if(params["cohort"] == @new_cohort, do: nil, else: params["cohort"]))
      |> Map.merge(category_attrs(params))

    case AdCategories.create_rows(attrs, params["labels"] || "") do
      {:ok, %{rows: rows, cohort: cohort}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created #{length(rows)} row(s) in cohort #{cohort}")
         |> push_patch(to: ~p"/admin/ad_categories")}

      {:error, reason} ->
        {:noreply,
         assign(socket, new_form: to_form(params, as: :new), new_error: error_text(reason))}
    end
  end

  def handle_event("validate", %{"ad_category" => attrs}, socket) do
    changeset =
      socket.assigns.row
      |> AdCategories.change_row(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"ad_category" => attrs}, socket) do
    case AdCategories.update_row(socket.assigns.row, attrs) do
      {:ok, row} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved #{row.row_id}")
         |> push_patch(to: ~p"/admin/ad_categories")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  @impl true
  def handle_info({SearchSelect, "remap-target", value}, socket) do
    {:noreply, update(socket, :remap, &(&1 && %{&1 | target: value}))}
  end

  defp category_attrs(%{"category_id" => @new_category} = params) do
    %{
      "new_category" => %{
        "category_name" => String.trim(params["category_name"] || ""),
        "category_label" => String.trim(params["category_label"] || "")
      }
    }
  end

  defp category_attrs(params), do: %{"category_id" => params["category_id"]}

  defp prune_selector(socket) do
    filters = socket.assigns.filters
    selector = Map.reject(filters, fn {_k, v} -> v == "" end)
    if selector == %{}, do: %{"all" => true}, else: selector
  end

  defp toggle(set, value) do
    if MapSet.member?(set, value), do: MapSet.delete(set, value), else: MapSet.put(set, value)
  end

  defp error_text(%Ecto.Changeset{} = changeset) do
    changeset
    |> AdCategories.changeset_errors()
    |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end

  defp error_text({label, reason}) when is_binary(label), do: "#{label}: #{error_text(reason)}"

  defp error_text({:in_use, count}),
    do: "Still used by #{count} media piece(s). Remap them or deactivate the row."

  defp error_text({:row_inactive, row_id}), do: "#{row_id} is inactive"
  defp error_text({:not_found, row_id}), do: "#{row_id} not found"
  defp error_text(:no_labels), do: "Enter at least one ad label"
  defp error_text(:unknown_category), do: "Choose a category"
  defp error_text(:invalid_cohort), do: "Cohort must be legacy or YYMMDD-xxxx"
  defp error_text(:immutable_key), do: "row_id and category_id can't change"
  defp error_text(other), do: inspect(other)

  defp cohort_options(cohorts, current \\ nil) do
    values = Enum.map(cohorts, & &1.cohort)
    values = if current && current not in values, do: [current | values], else: values
    Enum.map(values, &{&1, &1})
  end

  defp in_use_count(rows), do: Enum.count(rows, &(&1.media_pieces_count > 0))

  defp meta_tags(nil), do: []
  defp meta_tags(value), do: value |> String.split("|", trim: true) |> Enum.map(&String.trim/1)

  defp filtered?(filters), do: Enum.any?(filters, fn {_k, v} -> v != "" end)

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <%= case @live_action do %>
              <% :index -> %>
                {render_index(assigns)}
              <% :new -> %>
                {render_new(assigns)}
              <% :edit -> %>
                {render_edit(assigns)}
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp render_index(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Ad categories"
        count={@total_count}
        subtitle="The ad taxonomy media pieces are filed under, grouped by category."
      >
        <:actions>
          <button
            type="button"
            class="btn btn-sm btn-ghost text-error"
            phx-click="prune_preview"
          >
            <.icon name="hero-trash" class="size-4" /> Delete unused
          </button>
          <.link patch={~p"/admin/ad_categories/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New rows
          </.link>
        </:actions>
      </.page_header>

      <.form
        for={%{}}
        as={:filters}
        id="ad-category-filters"
        phx-change="filter"
        class="mb-4 flex flex-wrap items-center gap-3"
      >
        <label class="input min-w-64 grow sm:max-w-sm">
          <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
          <input
            type="text"
            name="filters[q]"
            value={@filters["q"]}
            placeholder="Search labels, names, row ids, keywords"
            phx-debounce="300"
            autocomplete="off"
            class="grow"
          />
        </label>
        <select name="filters[category_id]" class="select w-auto">
          <option value="">All categories</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(@categories, &{"#{&1.category_id} #{&1.category_label}", &1.category_id}),
            @filters["category_id"]
          )}
        </select>
        <select name="filters[cohort]" class="select w-auto">
          <option value="">All cohorts</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(@cohorts, &{"#{&1.cohort} (#{&1.count})", &1.cohort}),
            @filters["cohort"]
          )}
        </select>
        <select name="filters[active]" class="select w-auto">
          {Phoenix.HTML.Form.options_for_select(
            [{"Active and inactive", ""}, {"Active only", "true"}, {"Inactive only", "false"}],
            @filters["active"]
          )}
        </select>
        <button
          :if={filtered?(@filters)}
          type="button"
          class="btn btn-sm btn-ghost"
          phx-click="clear_filters"
        >
          Clear
        </button>
      </.form>

      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-base-content/60">
          Showing {length(@rows)} of {@total_count} rows in {length(@groups)} categories
        </p>
        <div class="flex flex-wrap items-center gap-1">
          <details class="dropdown dropdown-end">
            <summary class="btn btn-sm btn-ghost">
              <.icon name="hero-bars-3" class="size-4" /> Jump to category
            </summary>
            <ul class="dropdown-content menu z-20 max-h-96 w-80 flex-nowrap overflow-y-auto rounded-box border border-base-300 bg-base-100 p-2 shadow-sm">
              <li :for={group <- @groups}>
                <a href={"#cat-#{group.category_id}"}>
                  <span class="font-mono text-xs text-base-content/50">{group.category_id}</span>
                  {group.category_label}
                </a>
              </li>
            </ul>
          </details>
          <button type="button" class="btn btn-sm btn-ghost" phx-click="expand_all">
            Expand all
          </button>
          <button type="button" class="btn btn-sm btn-ghost" phx-click="collapse_all">
            Collapse all
          </button>
        </div>
      </div>

      <div
        :if={MapSet.size(@selected) > 0}
        id="bulk-bar"
        class="sticky top-0 z-10 mb-4 flex flex-wrap items-center gap-3 rounded-2xl border border-primary/30 bg-base-100/95 px-6 py-3 shadow-sm backdrop-blur"
      >
        <span class="text-sm font-semibold">{MapSet.size(@selected)} selected</span>
        <form id="bulk-cohort-form" phx-submit="bulk_cohort" class="flex items-center gap-2">
          <select name="cohort" class="select select-sm w-auto">
            <option value="__new__">New cohort {@new_cohort_value}</option>
            {Phoenix.HTML.Form.options_for_select(cohort_options(@cohorts), nil)}
          </select>
          <button class="btn btn-primary btn-sm">Move to cohort</button>
        </form>
        <button type="button" class="btn btn-sm btn-ghost ml-auto" phx-click="clear_selection">
          Clear
        </button>
      </div>

      <.panel :if={@groups == []} flush>
        <.empty_state icon="hero-magnifying-glass" title="No rows match these filters.">
          <:action :if={filtered?(@filters)}>
            <button type="button" phx-click="clear_filters" class="btn btn-sm btn-ghost">
              Clear filters
            </button>
          </:action>
        </.empty_state>
      </.panel>

      <div class="space-y-4">
        <section
          :for={group <- @groups}
          id={"cat-#{group.category_id}"}
          class="scroll-mt-4 rounded-2xl border border-base-300 bg-surface shadow-sm dark:bg-base-100"
        >
          <header class={[
            "flex flex-wrap items-center gap-3 px-6 py-4",
            not MapSet.member?(@collapsed, group.category_id) && "border-b border-base-300"
          ]}>
            <button
              type="button"
              class="btn btn-ghost btn-xs btn-square"
              phx-click="toggle_category"
              phx-value-id={group.category_id}
              aria-expanded={to_string(not MapSet.member?(@collapsed, group.category_id))}
              aria-label={"Toggle #{group.category_id}"}
            >
              <.icon
                name={
                  if MapSet.member?(@collapsed, group.category_id),
                    do: "hero-chevron-right",
                    else: "hero-chevron-down"
                }
                class="size-4"
              />
            </button>
            <.chip class="font-mono">{group.category_id}</.chip>
            <div class="min-w-0 grow">
              <h2 class="font-semibold">{group.category_label}</h2>
              <p class="text-xs text-base-content/50">{group.category_name}</p>
            </div>
            <span class="text-sm text-base-content/60">
              {length(group.rows)} rows, {in_use_count(group.rows)} in use
            </span>
            <div class="flex items-center gap-1">
              <button
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="select_category"
                phx-value-id={group.category_id}
              >
                Select
              </button>
              <button
                type="button"
                class="btn btn-sm btn-ghost"
                phx-click="open_category"
                phx-value-id={group.category_id}
              >
                <.icon name="hero-pencil-square" class="size-4" /> Edit category
              </button>
            </div>
          </header>

          <div :if={not MapSet.member?(@collapsed, group.category_id)} class="overflow-x-auto">
            <table class="w-full text-left text-sm">
              <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
                <tr>
                  <th class="w-0 py-3 pr-0 pl-6"><span class="sr-only">Select</span></th>
                  <th class="px-6 py-3 font-medium">Row</th>
                  <th class="px-6 py-3 font-medium">Ad label</th>
                  <th class="px-6 py-3 font-medium">Age</th>
                  <th class="px-6 py-3 font-medium">Channel</th>
                  <th class="px-6 py-3 font-medium">Cohort</th>
                  <th class="px-6 py-3 font-medium">Status</th>
                  <th class="px-6 py-3 font-medium whitespace-nowrap">Ads (all / active)</th>
                  <th class="px-6 py-3"><span class="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300">
                <%= for row <- group.rows do %>
                  <tr
                    id={"row-#{row.id}"}
                    class={[
                      "transition-colors hover:bg-base-200/40",
                      MapSet.member?(@selected, row.id) && "bg-primary/5",
                      !row.active && "opacity-60"
                    ]}
                  >
                    <td class="w-0 py-3 pr-0 pl-6 align-middle">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        checked={MapSet.member?(@selected, row.id)}
                        phx-click="toggle_select"
                        phx-value-id={row.id}
                        aria-label={"Select #{row.row_id}"}
                      />
                    </td>
                    <td class="px-6 py-3 font-mono text-xs whitespace-nowrap text-base-content/60">
                      {row.row_id}
                    </td>
                    <td class="px-6 py-3 font-medium">{row.ad_label}</td>
                    <td class="px-6 py-3">
                      <.status_badge :if={row.age_gated} tone="warning">
                        {row.age_min}+
                      </.status_badge>
                    </td>
                    <td class="px-6 py-3 text-xs text-base-content/70">
                      {row.sales_channel_default}
                    </td>
                    <td class="px-6 py-3">
                      <.chip class={[
                        "whitespace-nowrap",
                        row.cohort == "legacy" && "text-base-content/50"
                      ]}>
                        {row.cohort}
                      </.chip>
                    </td>
                    <td class="px-6 py-3">
                      <.status_badge :if={row.active} tone="success">Active</.status_badge>
                      <.status_badge :if={!row.active}>Inactive</.status_badge>
                    </td>
                    <td class="px-6 py-3 whitespace-nowrap">
                      {row.media_pieces_count}
                      <span class="text-base-content/50">/ {row.active_media_pieces_count}</span>
                    </td>
                    <td class="w-0 px-6 py-3">
                      <div class="flex items-center justify-end gap-1">
                        <.row_button
                          icon={
                            if MapSet.member?(@details, row.id),
                              do: "hero-chevron-up",
                              else: "hero-chevron-down"
                          }
                          label="Details"
                          phx-click="toggle_details"
                          phx-value-id={row.id}
                          aria-expanded={to_string(MapSet.member?(@details, row.id))}
                        />
                        <.icon_button
                          icon="hero-pencil-square"
                          label="Edit"
                          patch={~p"/admin/ad_categories/#{row.id}/edit"}
                        />
                        <.row_button
                          :if={row.media_pieces_count > 0}
                          icon="hero-arrows-right-left"
                          label="Remap"
                          phx-click="open_remap"
                          phx-value-id={row.id}
                        />
                        <.row_button
                          :if={row.media_pieces_count > 0}
                          icon={if row.active, do: "hero-no-symbol", else: "hero-check-circle"}
                          label={if row.active, do: "Deactivate", else: "Activate"}
                          phx-click="set_active"
                          phx-value-id={row.id}
                          phx-value-active={to_string(!row.active)}
                        />
                        <.row_button
                          :if={row.media_pieces_count == 0}
                          icon="hero-trash"
                          label="Delete"
                          tone="error"
                          phx-click="delete"
                          phx-value-id={row.id}
                          data-confirm={"Delete #{row.row_id} #{row.ad_label}?"}
                        />
                      </div>
                    </td>
                  </tr>
                  <tr
                    :if={MapSet.member?(@details, row.id)}
                    id={"details-#{row.id}"}
                    class="bg-base-200/40"
                  >
                    <td></td>
                    <td colspan="8" class="space-y-1.5 px-6 py-3">
                      <div
                        :for={
                          {label, value} <- [
                            {"Meta 1", row.meta_1},
                            {"Meta 2", row.meta_2},
                            {"Meta 3", row.meta_3}
                          ]
                        }
                        class="flex flex-wrap items-center gap-1"
                      >
                        <span class="w-14 text-xs text-base-content/50">{label}</span>
                        <.chip :for={tag <- meta_tags(value)}>{tag}</.chip>
                        <span :if={meta_tags(value) == []} class="text-xs text-base-content/40">
                          None
                        </span>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      </div>

      <p class="mt-6 text-xs text-base-content/50">{AdCategories.iab_attribution()}</p>

      <.modal
        :if={@remap}
        id="remap-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,36rem)]"
      >
        <.modal_body
          title={"Remap #{@remap.row.row_id} #{@remap.row.ad_label}"}
          description={"Moves all #{@remap.count} media piece(s) on this row to the target row you pick."}
        >
          <.live_component
            module={SearchSelect}
            id="remap-target"
            name="remap_target"
            value={nil}
            label="Target row"
            options={@remap.options}
          />
          <:footer>
            <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
            <button
              type="button"
              class="btn btn-primary"
              phx-click="confirm_remap"
              disabled={is_nil(@remap.target)}
            >
              Move {@remap.count} media piece(s)
            </button>
          </:footer>
        </.modal_body>
      </.modal>

      <.modal
        :if={@prune}
        id="prune-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,36rem)]"
      >
        <.modal_body title="Delete unused rows">
          <%= if @prune.count == 0 do %>
            <p class="text-sm text-base-content/70">No unused rows match the current filters.</p>
          <% else %>
            <p class="text-sm text-base-content/70">
              {@prune.count} row(s) {if filtered?(@filters),
                do: "matching the current filters",
                else: "in the whole taxonomy"} have no media pieces and will be deleted.
            </p>
            <div class="max-h-48 overflow-y-auto rounded-xl border border-base-300 bg-base-200/40 px-4 py-3 font-mono text-xs text-base-content/70">
              {Enum.join(@prune.deleted, ", ")}
            </div>
          <% end %>
          <:footer>
            <%= if @prune.count == 0 do %>
              <button type="button" class="btn" phx-click="close_modal">Close</button>
            <% else %>
              <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
              <button type="button" class="btn btn-error" phx-click="confirm_prune">
                Delete {@prune.count} row(s)
              </button>
            <% end %>
          </:footer>
        </.modal_body>
      </.modal>

      <.modal
        :if={@category_edit}
        id="category-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,32rem)]"
      >
        <.form for={@category_edit.form} id="category-form" phx-submit="save_category">
          <.modal_body
            title={"Edit category #{@category_edit.category.category_id}"}
            description="Renames every row in this category."
          >
            <div>
              <.input field={@category_edit.form[:category_name]} label="Category name" required />
              <.input
                field={@category_edit.form[:category_label]}
                label="Category label"
                required
              />
            </div>
            <p :if={@category_edit.error} class="text-sm text-error">{@category_edit.error}</p>
            <:footer>
              <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
              <.button variant="primary">Save</.button>
            </:footer>
          </.modal_body>
        </.form>
      </.modal>
    </.page>
    """
  end

  defp render_new(assigns) do
    ~H"""
    <.page class="max-w-3xl">
      <.page_header
        title="New ad category rows"
        subtitle="Pick a category, then enter one ad label per line. Every new row gets the next row id in the category and shares one cohort."
        back_to={~p"/admin/ad_categories"}
        back_label="Ad categories"
      />

      <.form
        for={@new_form}
        id="new-rows-form"
        phx-change="validate_new"
        phx-submit="save_new"
      >
        <.panel>
          <div>
            <.input
              field={@new_form[:category_id]}
              type="select"
              label="Category"
              prompt="Choose a category"
              options={
                Enum.map(@categories, &{"#{&1.category_id} #{&1.category_label}", &1.category_id}) ++
                  [{"Create a new category", "__new__"}]
              }
              required
            />
            <div
              :if={@new_form[:category_id].value == "__new__"}
              class="grid gap-x-4 sm:grid-cols-2"
            >
              <.input field={@new_form[:category_name]} label="Category name" required />
              <.input field={@new_form[:category_label]} label="Category label" required />
            </div>
            <.input
              field={@new_form[:labels]}
              type="textarea"
              label={"Ad labels, one per line (max #{AdCategory.ad_label_max()} characters each)"}
              rows="6"
              required
            />
            <.input
              field={@new_form[:cohort]}
              type="select"
              label="Cohort"
              options={[{"New cohort (generated)", "__new__"} | cohort_options(@cohorts)]}
            />
            <div class="grid gap-x-4 sm:grid-cols-3">
              <.input
                field={@new_form[:age_gated]}
                type="select"
                label="Age gated"
                options={[{"No", "false"}, {"Yes", "true"}]}
              />
              <.input
                field={@new_form[:age_min]}
                type="select"
                label="Minimum age"
                prompt="None"
                options={Enum.map(AdCategory.age_mins(), &{"#{&1}+", &1})}
              />
              <.input
                field={@new_form[:sales_channel_default]}
                type="select"
                label="Sales channel"
                prompt="None"
                options={AdCategory.sales_channels()}
              />
            </div>
            <.input field={@new_form[:meta_1]} label="Meta 1 (pipe separated keywords)" />
            <.input field={@new_form[:meta_2]} label="Meta 2" />
            <.input field={@new_form[:meta_3]} label="Meta 3 (Overture slugs, free text)" />
          </div>
          <p :if={@new_error} class="text-sm text-error">{@new_error}</p>
          <:footer>
            <.link patch={~p"/admin/ad_categories"} class="btn btn-ghost">Cancel</.link>
            <.button variant="primary" phx-disable-with="Saving...">Create rows</.button>
          </:footer>
        </.panel>
      </.form>

      <p class="mt-6 text-xs text-base-content/50">{AdCategories.iab_attribution()}</p>
    </.page>
    """
  end

  defp render_edit(assigns) do
    ~H"""
    <.page class="max-w-3xl">
      <.page_header
        title={"Edit #{@row.ad_label}"}
        subtitle={"Category #{@row.category_id} #{@row.category_label}"}
        back_to={~p"/admin/ad_categories"}
        back_label="Ad categories"
      >
        <:badges>
          <.chip class="font-mono">{@row.row_id}</.chip>
        </:badges>
      </.page_header>

      <.form for={@form} id="ad-category-form" phx-change="validate" phx-submit="save">
        <.panel>
          <div>
            <.input
              field={@form[:ad_label]}
              label={"Ad label (max #{AdCategory.ad_label_max()} characters)"}
              required
            />
            <div class="grid gap-x-4 sm:grid-cols-3">
              <.input
                field={@form[:age_gated]}
                type="select"
                label="Age gated"
                options={[{"No", "false"}, {"Yes", "true"}]}
              />
              <.input
                field={@form[:age_min]}
                type="select"
                label="Minimum age"
                prompt="None"
                options={Enum.map(AdCategory.age_mins(), &{"#{&1}+", &1})}
              />
              <.input
                field={@form[:sales_channel_default]}
                type="select"
                label="Sales channel"
                prompt="None"
                options={AdCategory.sales_channels()}
              />
            </div>
            <.input field={@form[:meta_1]} label="Meta 1 (pipe separated keywords)" />
            <.input field={@form[:meta_2]} label="Meta 2" />
            <.input field={@form[:meta_3]} label="Meta 3 (Overture slugs, free text)" />
            <div class="grid gap-x-4 sm:grid-cols-3">
              <.input field={@form[:sort_order]} type="number" label="Sort order" />
              <.input
                field={@form[:cohort]}
                type="select"
                label="Cohort"
                options={cohort_options(@cohorts, @row.cohort)}
              />
              <.input
                field={@form[:active]}
                type="select"
                label="Status"
                options={[{"Active", "true"}, {"Inactive", "false"}]}
              />
            </div>
          </div>
          <:footer>
            <.link patch={~p"/admin/ad_categories"} class="btn btn-ghost">Cancel</.link>
            <.button variant="primary" phx-disable-with="Saving...">Save</.button>
          </:footer>
        </.panel>
      </.form>

      <p class="mt-6 text-xs text-base-content/50">{AdCategories.iab_attribution()}</p>
    </.page>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral error)
  attr :rest, :global

  defp row_button(assigns) do
    ~H"""
    <button
      type="button"
      class={["btn btn-ghost btn-sm btn-square", @tone == "error" && "text-error"]}
      title={@label}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
      <span class="sr-only">{@label}</span>
    </button>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true
  slot :footer, required: true

  defp modal_body(assigns) do
    ~H"""
    <div>
      <header class="px-6 pt-6 pr-14 pb-4">
        <h3 class="text-lg font-semibold">{@title}</h3>
        <p :if={@description} class="mt-1 text-sm text-base-content/60">{@description}</p>
      </header>
      <div class="space-y-4 px-6 pb-6">{render_slot(@inner_block)}</div>
      <footer class="flex flex-wrap items-center justify-end gap-2 border-t border-base-300 bg-base-200/40 px-6 py-4">
        {render_slot(@footer)}
      </footer>
    </div>
    """
  end
end
