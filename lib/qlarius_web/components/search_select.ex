defmodule QlariusWeb.Components.SearchSelect do
  @moduledoc """
  A server-side searchable select for long option lists.

      <.live_component
        module={QlariusWeb.Components.SearchSelect}
        id="ad-category-picker"
        field={f[:ad_category_id]}
        options={@ad_category_options}
        label="Ad Category"
      />

  Options are maps with `:value`, `:label`, `:group` and an optional
  `:search_text`. The selected value is submitted through a hidden input named
  after the field. The search box has no name and belongs to a detached form id,
  so it never lands in the parent form's params and Enter never submits it.

  On every pick or clear the component sends `{SearchSelect, id, value}` to the
  LiveView process that renders it.
  """

  use QlariusWeb, :live_component

  @default_limit 50

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       query: "",
       open?: false,
       mode: :search,
       active_index: 0,
       expanded: MapSet.new(),
       input_key: 0,
       label: nil,
       placeholder: "Type words to search",
       required: false,
       empty_text: "No matches",
       limit: @default_limit,
       footer: []
     )}
  end

  @impl true
  def update(assigns, socket) do
    first_update? = not Map.has_key?(socket.assigns, :selected)

    {name, value, errors} = field_parts(assigns)

    socket =
      socket
      |> assign(Map.drop(assigns, [:field, :value]))
      |> assign(:name, name)
      |> assign(:errors, errors)
      |> assign(
        :options,
        Enum.map(assigns[:options] || socket.assigns[:options] || [], &normalize/1)
      )

    socket =
      if first_update? do
        selected = to_value(value)

        assign(socket,
          selected: selected,
          expanded: initial_expanded(socket.assigns.options, selected)
        )
      else
        socket
      end

    {:ok, socket}
  end

  defp field_parts(%{field: %Phoenix.HTML.FormField{} = field}) do
    {field.name, field.value, Enum.map(field.errors, &translate_error/1)}
  end

  defp field_parts(assigns), do: {assigns[:name], assigns[:value], assigns[:errors] || []}

  @impl true
  def handle_event("open", _params, socket), do: {:noreply, assign(socket, open?: true)}

  def handle_event("close", _params, socket), do: {:noreply, assign(socket, open?: false)}

  def handle_event("search", %{"value" => query}, socket) do
    {:noreply, set_query(socket, query)}
  end

  def handle_event("key", %{"key" => key} = params, socket) do
    socket =
      case params do
        %{"value" => value} when is_binary(value) and key != "Escape" -> set_query(socket, value)
        _ -> socket
      end

    {:noreply, handle_key(socket, key)}
  end

  def handle_event("pick", %{"option" => value}, socket), do: {:noreply, pick(socket, value)}

  def handle_event("clear", _params, socket), do: {:noreply, pick(socket, nil)}

  def handle_event("mode", %{"mode" => mode}, socket) when mode in ~w(search browse) do
    mode = String.to_existing_atom(mode)
    {:noreply, assign(socket, mode: mode, open?: true, active_index: 0)}
  end

  def handle_event("toggle_group", %{"group" => group}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, group),
        do: MapSet.delete(socket.assigns.expanded, group),
        else: MapSet.put(socket.assigns.expanded, group)

    {:noreply, assign(socket, expanded: expanded, active_index: 0)}
  end

  def handle_event("expand_all", _params, socket) do
    groups = socket.assigns.options |> Enum.map(& &1.group) |> MapSet.new()
    {:noreply, assign(socket, expanded: groups)}
  end

  def handle_event("collapse_all", _params, socket) do
    {:noreply, assign(socket, expanded: MapSet.new(), active_index: 0)}
  end

  defp set_query(socket, query) do
    cond do
      query == socket.assigns.query ->
        socket

      socket.assigns.mode == :browse and String.trim(query) == "" ->
        assign(socket, query: query)

      true ->
        assign(socket, query: query, mode: :search, open?: true, active_index: 0)
    end
  end

  defp handle_key(socket, "ArrowDown"), do: move(socket, 1)
  defp handle_key(socket, "ArrowUp"), do: move(socket, -1)
  defp handle_key(socket, "Escape"), do: assign(socket, open?: false)

  defp handle_key(socket, "Enter") do
    case Enum.at(navigable(socket.assigns), socket.assigns.active_index) do
      nil -> socket
      option -> pick(socket, option.value)
    end
  end

  defp handle_key(socket, _key), do: socket

  defp move(socket, step) do
    count = length(navigable(socket.assigns))

    if count == 0 do
      assign(socket, open?: true)
    else
      index =
        if socket.assigns.open?,
          do: rem(socket.assigns.active_index + step + count, count),
          else: 0

      assign(socket, active_index: index, open?: true)
    end
  end

  defp pick(socket, value) do
    selected = to_value(value)
    send(self(), {__MODULE__, socket.assigns.id, selected})

    expanded =
      case Enum.find(socket.assigns.options, &(&1.value == selected)) do
        nil -> socket.assigns.expanded
        option -> MapSet.put(socket.assigns.expanded, option.group)
      end

    assign(socket,
      selected: selected,
      query: "",
      open?: false,
      active_index: 0,
      expanded: expanded,
      input_key: socket.assigns.input_key + 1
    )
  end

  @doc false
  def search(options, query, limit \\ @default_limit) do
    terms = terms(query)

    matches =
      Enum.filter(options, fn option ->
        Enum.all?(terms, &String.contains?(option.search_text, &1))
      end)

    {in_label, others} =
      Enum.split_with(matches, fn option ->
        label = String.downcase(option.label)
        Enum.all?(terms, &String.contains?(label, &1))
      end)

    ranked = in_label ++ others
    {Enum.take(ranked, limit), length(ranked)}
  end

  defp terms(query), do: query |> String.downcase() |> String.split(~r/\s+/, trim: true)

  defp navigable(%{mode: :browse} = assigns) do
    Enum.filter(assigns.options, &MapSet.member?(assigns.expanded, &1.group))
  end

  defp navigable(assigns) do
    if terms(assigns.query) == [] do
      []
    else
      assigns.options |> search(assigns.query, assigns.limit) |> elem(0)
    end
  end

  defp groups(options) do
    grouped = Enum.group_by(options, & &1.group)

    options
    |> Enum.map(& &1.group)
    |> Enum.uniq()
    |> Enum.map(&{&1, Map.fetch!(grouped, &1)})
  end

  defp initial_expanded(options, selected) do
    case Enum.find(options, &(&1.value == selected)) do
      nil -> MapSet.new()
      option -> MapSet.new([option.group])
    end
  end

  defp normalize(option) do
    option
    |> Map.update!(:value, &to_value/1)
    |> Map.put_new(:group, nil)
    |> Map.put_new_lazy(:search_text, fn -> String.downcase(option.label) end)
  end

  defp to_value(nil), do: nil
  defp to_value(""), do: nil
  defp to_value(value), do: to_string(value)

  defp option_dom_id(id, option), do: "#{id}-opt-#{option.value}"

  @impl true
  def render(assigns) do
    navigable = navigable(assigns)
    active = Enum.at(navigable, assigns.active_index)

    {results, total} =
      if assigns.mode == :search and terms(assigns.query) != [],
        do: search(assigns.options, assigns.query, assigns.limit),
        else: {[], 0}

    assigns =
      assign(assigns,
        active_value: active && active.value,
        active_dom_id: active && option_dom_id(assigns.id, active),
        results: results,
        total: total,
        selected_option: Enum.find(assigns.options, &(&1.value == assigns.selected)),
        groups: if(assigns.mode == :browse, do: groups(assigns.options), else: [])
      )

    ~H"""
    <div id={@id} class="fieldset mb-2" phx-click-away="close" phx-target={@myself}>
      <label :if={@label} for={"#{@id}-search-#{@input_key}"} class="fieldset-label mb-1">
        {@label}<span :if={@required} class="text-error">*</span>
      </label>

      <input type="hidden" name={@name} id={"#{@id}-value"} value={@selected || ""} />

      <div :if={@selected_option} class="flex items-center gap-2 mb-2">
        <span class="badge badge-primary badge-lg h-auto py-1 gap-2">
          {@selected_option.label}
          <span :if={@selected_option.group} class="opacity-75 text-xs">
            {@selected_option.group}
          </span>
        </span>
        <button
          type="button"
          class="btn btn-ghost btn-xs"
          phx-click="clear"
          phx-target={@myself}
          aria-label="Clear selection"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div class="flex gap-2">
        <input
          type="text"
          id={"#{@id}-search-#{@input_key}"}
          form={"#{@id}-detached"}
          value={@query}
          placeholder={@placeholder}
          autocomplete="off"
          role="combobox"
          aria-expanded={to_string(@open?)}
          aria-controls={"#{@id}-listbox"}
          aria-activedescendant={@open? && @active_dom_id}
          class={["w-full input input-bordered", @errors != [] && "input-error"]}
          phx-keyup="search"
          phx-debounce="200"
          phx-keydown="key"
          phx-focus="open"
          phx-target={@myself}
        />
        <button
          type="button"
          class={["btn", @mode == :browse && @open? && "btn-active"]}
          phx-click="mode"
          phx-value-mode="browse"
          phx-target={@myself}
        >
          Browse all
        </button>
      </div>

      <div
        :if={@open?}
        id={"#{@id}-listbox"}
        role="listbox"
        class="mt-1 rounded-box border border-base-300 bg-base-100 shadow-lg"
      >
        <div class="flex items-center justify-between gap-2 border-b border-base-300 px-3 py-2">
          <div role="tablist" class="tabs tabs-box tabs-sm">
            <button
              type="button"
              role="tab"
              class={["tab", @mode == :search && "tab-active"]}
              phx-click="mode"
              phx-value-mode="search"
              phx-target={@myself}
            >
              Search
            </button>
            <button
              type="button"
              role="tab"
              class={["tab", @mode == :browse && "tab-active"]}
              phx-click="mode"
              phx-value-mode="browse"
              phx-target={@myself}
            >
              Browse all
            </button>
          </div>
          <div :if={@mode == :browse} class="flex gap-1">
            <button
              type="button"
              class="btn btn-ghost btn-xs"
              phx-click="expand_all"
              phx-target={@myself}
            >
              Expand all
            </button>
            <button
              type="button"
              class="btn btn-ghost btn-xs"
              phx-click="collapse_all"
              phx-target={@myself}
            >
              Collapse all
            </button>
          </div>
        </div>

        <div class="max-h-96 overflow-y-auto py-1">
          <%= if @mode == :search do %>
            <div
              :if={@results == [] && String.trim(@query) == ""}
              class="px-3 py-3 text-sm text-base-content/70"
            >
              Type one or more words to find a match, or <button
                type="button"
                class="link link-primary"
                phx-click="mode"
                phx-value-mode="browse"
                phx-target={@myself}
              >
                browse the full list
              </button>.
            </div>
            <div
              :if={@results == [] && String.trim(@query) != ""}
              class="px-3 py-3 text-sm text-base-content/70"
            >
              {@empty_text}
            </div>
            <.option
              :for={option <- @results}
              id={option_dom_id(@id, option)}
              option={option}
              selected={option.value == @selected}
              active={option.value == @active_value}
              show_group
              target={@myself}
            />
            <div :if={@total > length(@results)} class="px-3 py-2 text-xs text-base-content/60">
              Showing {length(@results)} of {@total}, add a word to narrow
            </div>
          <% else %>
            <div :for={{group, options} <- @groups} class="border-b border-base-200 last:border-b-0">
              <button
                type="button"
                class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm font-semibold hover:bg-base-200"
                phx-click="toggle_group"
                phx-value-group={group}
                phx-target={@myself}
                aria-expanded={to_string(MapSet.member?(@expanded, group))}
              >
                <.icon
                  name={
                    if MapSet.member?(@expanded, group),
                      do: "hero-chevron-down",
                      else: "hero-chevron-right"
                  }
                  class="size-4"
                />
                <span class="flex-1">{group || "Other"} ({length(options)})</span>
              </button>
              <div :if={MapSet.member?(@expanded, group)} class="pb-1">
                <.option
                  :for={option <- options}
                  id={option_dom_id(@id, option)}
                  option={option}
                  selected={option.value == @selected}
                  active={option.value == @active_value}
                  show_group={false}
                  target={@myself}
                />
              </div>
            </div>
          <% end %>
        </div>

        <div
          :if={@footer != []}
          class="border-t border-base-300 px-3 py-2 text-xs text-base-content/60"
        >
          {render_slot(@footer)}
        </div>
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :option, :map, required: true
  attr :selected, :boolean, default: false
  attr :active, :boolean, default: false
  attr :show_group, :boolean, default: true
  attr :target, :any, required: true

  defp option(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      role="option"
      aria-selected={to_string(@selected)}
      class={[
        "flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-base-200",
        @active && "bg-base-200"
      ]}
      phx-click="pick"
      phx-value-option={@option.value}
      phx-target={@target}
    >
      <.icon
        name="hero-check"
        class={"size-4 shrink-0 text-primary #{if !@selected, do: "invisible"}"}
      />
      <span class="flex-1">{@option.label}</span>
      <span :if={@show_group && @option.group} class="text-xs text-base-content/60">
        {@option.group}
      </span>
    </button>
    """
  end
end
