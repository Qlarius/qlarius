defmodule QlariusWeb.Admin.AdCategoryManagerLive do
  use QlariusWeb, :live_view

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
    <div class="p-6 space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 class="text-2xl font-bold">Ad Categories</h1>
          <p class="text-sm text-base-content/60">
            Showing {length(@rows)} of {@total_count} rows in {length(@groups)} categories
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <button type="button" class="btn btn-outline btn-error btn-sm" phx-click="prune_preview">
            <.icon name="hero-trash" class="size-4" /> Delete unused
          </button>
          <.link patch={~p"/admin/ad_categories/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New rows
          </.link>
        </div>
      </div>

      <.form
        for={%{}}
        as={:filters}
        id="ad-category-filters"
        phx-change="filter"
        class="flex flex-wrap items-end gap-3"
      >
        <label class="input input-bordered flex items-center gap-2 grow min-w-64">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-70" />
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
        <select name="filters[category_id]" class="select select-bordered">
          <option value="">All categories</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(@categories, &{"#{&1.category_id} #{&1.category_label}", &1.category_id}),
            @filters["category_id"]
          )}
        </select>
        <select name="filters[cohort]" class="select select-bordered">
          <option value="">All cohorts</option>
          {Phoenix.HTML.Form.options_for_select(
            Enum.map(@cohorts, &{"#{&1.cohort} (#{&1.count})", &1.cohort}),
            @filters["cohort"]
          )}
        </select>
        <select name="filters[active]" class="select select-bordered">
          {Phoenix.HTML.Form.options_for_select(
            [{"Active and inactive", ""}, {"Active only", "true"}, {"Inactive only", "false"}],
            @filters["active"]
          )}
        </select>
        <button
          :if={filtered?(@filters)}
          type="button"
          class="btn btn-ghost"
          phx-click="clear_filters"
        >
          Clear
        </button>
      </.form>

      <div class="flex flex-wrap items-center justify-between gap-2">
        <details class="dropdown">
          <summary class="btn btn-sm btn-ghost">
            <.icon name="hero-bars-3" class="size-4" /> Jump to category
          </summary>
          <ul class="dropdown-content menu z-20 max-h-96 w-80 flex-nowrap overflow-y-auto rounded-box bg-base-100 p-2 shadow">
            <li :for={group <- @groups}>
              <a href={"#cat-#{group.category_id}"}>
                <span class="font-mono text-xs">{group.category_id}</span>
                {group.category_label}
              </a>
            </li>
          </ul>
        </details>
        <div class="flex gap-1">
          <button type="button" class="btn btn-ghost btn-sm" phx-click="expand_all">
            Expand all
          </button>
          <button type="button" class="btn btn-ghost btn-sm" phx-click="collapse_all">
            Collapse all
          </button>
        </div>
      </div>

      <div
        :if={MapSet.size(@selected) > 0}
        id="bulk-bar"
        class="sticky top-0 z-10 flex flex-wrap items-center gap-3 rounded-box border border-primary/30 bg-base-100 p-3 shadow"
      >
        <span class="font-semibold">{MapSet.size(@selected)} selected</span>
        <form id="bulk-cohort-form" phx-submit="bulk_cohort" class="flex items-center gap-2">
          <select name="cohort" class="select select-bordered select-sm">
            <option value="__new__">New cohort {@new_cohort_value}</option>
            {Phoenix.HTML.Form.options_for_select(cohort_options(@cohorts), nil)}
          </select>
          <button class="btn btn-primary btn-sm">Move to cohort</button>
        </form>
        <button type="button" class="btn btn-ghost btn-sm" phx-click="clear_selection">Clear</button>
      </div>

      <div :if={@groups == []} class="rounded-box bg-base-100 p-8 text-center text-base-content/60">
        No rows match these filters.
      </div>

      <section
        :for={group <- @groups}
        id={"cat-#{group.category_id}"}
        class="rounded-box border border-base-300 bg-base-100 shadow-sm scroll-mt-4"
      >
        <header class="flex flex-wrap items-center gap-3 border-b border-base-300 px-4 py-3">
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
          <span class="badge badge-neutral font-mono text-white">{group.category_id}</span>
          <div class="grow">
            <div class="font-semibold">{group.category_label}</div>
            <div class="text-xs text-base-content/60">{group.category_name}</div>
          </div>
          <span class="text-sm text-base-content/70">
            {length(group.rows)} rows, {in_use_count(group.rows)} in use
          </span>
          <button
            type="button"
            class="btn btn-ghost btn-xs"
            phx-click="select_category"
            phx-value-id={group.category_id}
          >
            Select
          </button>
          <button
            type="button"
            class="btn btn-ghost btn-xs"
            phx-click="open_category"
            phx-value-id={group.category_id}
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit category
          </button>
        </header>

        <div :if={not MapSet.member?(@collapsed, group.category_id)} class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th class="w-8"></th>
                <th>Row</th>
                <th>Ad label</th>
                <th>Age</th>
                <th>Channel</th>
                <th>Cohort</th>
                <th>Status</th>
                <th>Ads (all / active)</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- group.rows do %>
                <tr id={"row-#{row.id}"} class={[!row.active && "opacity-60"]}>
                  <td>
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      checked={MapSet.member?(@selected, row.id)}
                      phx-click="toggle_select"
                      phx-value-id={row.id}
                      aria-label={"Select #{row.row_id}"}
                    />
                  </td>
                  <td class="font-mono text-xs whitespace-nowrap">{row.row_id}</td>
                  <td class="font-medium">{row.ad_label}</td>
                  <td>
                    <span :if={row.age_gated} class="badge badge-warning badge-sm">
                      {row.age_min}+
                    </span>
                  </td>
                  <td class="text-xs">{row.sales_channel_default}</td>
                  <td>
                    <span class={[
                      "badge badge-sm whitespace-nowrap",
                      row.cohort == "legacy" && "badge-ghost"
                    ]}>
                      {row.cohort}
                    </span>
                  </td>
                  <td>
                    <span :if={row.active} class="badge badge-success badge-sm">Active</span>
                    <span :if={!row.active} class="badge badge-sm">Inactive</span>
                  </td>
                  <td class="whitespace-nowrap">
                    {row.media_pieces_count} / {row.active_media_pieces_count}
                  </td>
                  <td>
                    <div class="flex justify-end gap-1">
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="toggle_details"
                        phx-value-id={row.id}
                      >
                        Details
                      </button>
                      <.link
                        patch={~p"/admin/ad_categories/#{row.id}/edit"}
                        class="btn btn-ghost btn-xs"
                      >
                        Edit
                      </.link>
                      <button
                        :if={row.media_pieces_count > 0}
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="open_remap"
                        phx-value-id={row.id}
                      >
                        Remap
                      </button>
                      <button
                        :if={row.media_pieces_count == 0}
                        type="button"
                        class="btn btn-ghost btn-xs text-error"
                        phx-click="delete"
                        phx-value-id={row.id}
                        data-confirm={"Delete #{row.row_id} #{row.ad_label}?"}
                      >
                        Delete
                      </button>
                      <button
                        :if={row.media_pieces_count > 0}
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="set_active"
                        phx-value-id={row.id}
                        phx-value-active={to_string(!row.active)}
                      >
                        {if row.active, do: "Deactivate", else: "Activate"}
                      </button>
                    </div>
                  </td>
                </tr>
                <tr
                  :if={MapSet.member?(@details, row.id)}
                  id={"details-#{row.id}"}
                  class="bg-base-200/50"
                >
                  <td></td>
                  <td colspan="8" class="space-y-1 py-2">
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
                      <span class="w-14 text-xs text-base-content/60">{label}</span>
                      <span :for={tag <- meta_tags(value)} class="badge badge-outline badge-sm">
                        {tag}
                      </span>
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

      <p class="text-xs text-base-content/60">{AdCategories.iab_attribution()}</p>

      <.modal
        :if={@remap}
        id="remap-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,36rem)]"
      >
        <div class="space-y-4 p-6">
          <h3 class="text-lg font-bold">Remap {@remap.row.row_id} {@remap.row.ad_label}</h3>
          <p>
            Moves all {@remap.count} media piece(s) on this row to the target row you pick.
          </p>
          <.live_component
            module={SearchSelect}
            id="remap-target"
            name="remap_target"
            value={nil}
            label="Target row"
            options={@remap.options}
          />
          <div class="flex justify-end gap-2 pt-2">
            <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
            <button
              type="button"
              class="btn btn-primary"
              phx-click="confirm_remap"
              disabled={is_nil(@remap.target)}
            >
              Move {@remap.count} media piece(s)
            </button>
          </div>
        </div>
      </.modal>

      <.modal
        :if={@prune}
        id="prune-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,36rem)]"
      >
        <div class="space-y-4 p-6">
          <h3 class="text-lg font-bold">Delete unused rows</h3>
          <%= if @prune.count == 0 do %>
            <p>No unused rows match the current filters.</p>
            <div class="flex justify-end">
              <button type="button" class="btn" phx-click="close_modal">Close</button>
            </div>
          <% else %>
            <p>
              {@prune.count} row(s) {if filtered?(@filters),
                do: "matching the current filters",
                else: "in the whole taxonomy"} have no media pieces and will be deleted.
            </p>
            <div class="max-h-48 overflow-y-auto rounded bg-base-200 p-2 font-mono text-xs">
              {Enum.join(@prune.deleted, ", ")}
            </div>
            <div class="flex justify-end gap-2">
              <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
              <button type="button" class="btn btn-error" phx-click="confirm_prune">
                Delete {@prune.count} row(s)
              </button>
            </div>
          <% end %>
        </div>
      </.modal>

      <.modal
        :if={@category_edit}
        id="category-modal"
        show
        on_cancel={JS.push("close_modal")}
        panel_class="w-[min(100%,32rem)]"
      >
        <div class="space-y-4 p-6">
          <h3 class="text-lg font-bold">Edit category {@category_edit.category.category_id}</h3>
          <p class="text-sm text-base-content/70">Renames every row in this category.</p>
          <.form for={@category_edit.form} id="category-form" phx-submit="save_category">
            <.input field={@category_edit.form[:category_name]} label="Category name" required />
            <.input field={@category_edit.form[:category_label]} label="Category label" required />
            <p :if={@category_edit.error} class="text-sm text-error">{@category_edit.error}</p>
            <div class="flex justify-end gap-2 pt-2">
              <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
              <button class="btn btn-primary">Save</button>
            </div>
          </.form>
        </div>
      </.modal>
    </div>
    """
  end

  defp render_new(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl space-y-4 p-6">
      <.back navigate={~p"/admin/ad_categories"}>Back to ad categories</.back>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-2xl">New ad category rows</h2>
          <p class="text-base-content/70">
            Pick a category, then enter one ad label per line. Every new row gets the next row id in
            the category and shares one cohort.
          </p>
          <.form
            for={@new_form}
            id="new-rows-form"
            phx-change="validate_new"
            phx-submit="save_new"
            class="space-y-2"
          >
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
            <div :if={@new_form[:category_id].value == "__new__"} class="grid gap-2 sm:grid-cols-2">
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
            <div class="grid gap-2 sm:grid-cols-3">
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
            <p :if={@new_error} class="text-sm text-error">{@new_error}</p>
            <div class="flex gap-2 pt-2">
              <.button phx-disable-with="Saving..." class="btn btn-primary">Create rows</.button>
              <.link patch={~p"/admin/ad_categories"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
          <p class="pt-4 text-xs text-base-content/60">{AdCategories.iab_attribution()}</p>
        </div>
      </div>
    </div>
    """
  end

  defp render_edit(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl space-y-4 p-6">
      <.back navigate={~p"/admin/ad_categories"}>Back to ad categories</.back>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-2xl">Edit {@row.ad_label}</h2>
          <div class="flex flex-wrap gap-4 text-sm">
            <span>Row <span class="font-mono font-semibold">{@row.row_id}</span></span>
            <span>
              Category <span class="font-mono font-semibold">{@row.category_id}</span>
              {@row.category_label}
            </span>
          </div>
          <.form
            for={@form}
            id="ad-category-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <.input
              field={@form[:ad_label]}
              label={"Ad label (max #{AdCategory.ad_label_max()} characters)"}
              required
            />
            <div class="grid gap-2 sm:grid-cols-3">
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
            <div class="grid gap-2 sm:grid-cols-3">
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
            <div class="flex gap-2 pt-2">
              <.button phx-disable-with="Saving..." class="btn btn-primary">Save</.button>
              <.link patch={~p"/admin/ad_categories"} class="btn btn-ghost">Cancel</.link>
            </div>
          </.form>
          <p class="pt-4 text-xs text-base-content/60">{AdCategories.iab_attribution()}</p>
        </div>
      </div>
    </div>
    """
  end
end
