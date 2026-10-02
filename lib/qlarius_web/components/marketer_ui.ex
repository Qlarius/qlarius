defmodule QlariusWeb.Components.MarketerUI do
  @moduledoc """
  Shared layout pieces for the marketer campaign pages and the admin and
  creator list screens, so they read as one product.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import QlariusWeb.CoreComponents, only: [icon: 1]

  attr :class, :any, default: "max-w-7xl"
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div class={["mx-auto px-6 py-8", @class]}>{render_slot(@inner_block)}</div>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :back_to, :string, default: nil
  attr :back_label, :string, default: nil
  attr :count, :integer, default: nil

  attr :crumbs, :list,
    default: [],
    doc: "ancestor trail as `{label, path}` tuples; replaces the back link when given"

  slot :badges
  slot :actions

  def page_header(assigns) do
    ~H"""
    <header class="mb-8">
      <nav :if={@crumbs != []} aria-label="Breadcrumb" class="mb-3">
        <ol class="flex flex-wrap items-center gap-1.5 text-sm text-base-content/60">
          <li
            :for={{{label, path}, idx} <- Enum.with_index(@crumbs)}
            class="flex items-center gap-1.5"
          >
            <.icon :if={idx == 0} name="hero-arrow-left" class="size-4" />
            <.icon :if={idx > 0} name="hero-chevron-right" class="size-3.5 text-base-content/30" />
            <.link navigate={path} class="max-w-56 truncate hover:text-base-content">{label}</.link>
          </li>
        </ol>
      </nav>
      <.link
        :if={@back_to && @crumbs == []}
        navigate={@back_to}
        class="mb-3 inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-base-content"
      >
        <.icon name="hero-arrow-left" class="size-4" /> {@back_label}
      </.link>
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-3">
            <h1 class="text-2xl font-bold">{@title}</h1>
            <span
              :if={@count}
              class="rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium text-base-content/70"
            >
              {@count}
            </span>
            {render_slot(@badges)}
          </div>
          <p :if={@subtitle} class="mt-1 text-sm text-base-content/60">{@subtitle}</p>
        </div>
        <div :if={@actions != []} class="flex shrink-0 flex-wrap items-center gap-2">
          {render_slot(@actions)}
        </div>
      </div>
    </header>
    """
  end

  attr :id, :string, default: nil
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :flush, :boolean, default: false, doc: "drops body padding, for tables and lists"
  attr :class, :any, default: nil
  slot :actions
  slot :inner_block, required: true
  slot :footer

  def panel(assigns) do
    ~H"""
    <section
      id={@id}
      class={["rounded-2xl border border-base-300 bg-surface shadow-sm dark:bg-base-100", @class]}
    >
      <header
        :if={@title}
        class={[
          "flex items-start justify-between gap-4",
          if(@flush, do: "border-b border-base-300 px-6 py-4", else: "px-6 pt-6 pb-5")
        ]}
      >
        <div class="min-w-0">
          <h2 class="text-base font-semibold">{@title}</h2>
          <p :if={@description} class="mt-0.5 text-sm text-base-content/60">{@description}</p>
        </div>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-2">
          {render_slot(@actions)}
        </div>
      </header>
      <div class={[
        !@flush && "space-y-4 px-6 pb-6",
        !@flush && !@title && "pt-6"
      ]}>
        {render_slot(@inner_block)}
      </div>
      <footer
        :if={@footer != []}
        class="flex flex-wrap items-center justify-end gap-2 rounded-b-2xl border-t border-base-300 bg-base-200/40 px-6 py-4"
      >
        {render_slot(@footer)}
      </footer>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center px-6 py-14 text-center">
      <div class="mb-4 flex size-12 items-center justify-center rounded-full bg-base-200">
        <.icon name={@icon} class="size-6 text-base-content/50" />
      </div>
      <p class="font-semibold">{@title}</p>
      <p :if={@inner_block != []} class="mt-1 max-w-sm text-sm text-base-content/60">
        {render_slot(@inner_block)}
      </p>
      <div :if={@action != []} class="mt-5">{render_slot(@action)}</div>
    </div>
    """
  end

  attr :message, :string, required: true

  def no_marketer_notice(assigns) do
    ~H"""
    <.page class="max-w-3xl">
      <.panel>
        <.empty_state icon="hero-building-storefront" title="No marketer selected">
          {@message}
          <:action>
            <.link navigate={~p"/admin/marketers"} class="btn btn-primary">Choose a marketer</.link>
          </:action>
        </.empty_state>
      </.panel>
    </.page>
    """
  end

  attr :dirty, :boolean, required: true
  attr :id, :string, default: nil

  def unsaved_note(assigns) do
    ~H"""
    <p :if={@dirty} id={@id} class="mr-auto flex items-center gap-2 text-sm text-base-content/70">
      <span class="size-2 rounded-full bg-warning" aria-hidden="true"></span> Unsaved changes
    </p>
    """
  end

  attr :dirty, :boolean, required: true
  attr :note_id, :string, default: "unsaved-changes-note"
  slot :inner_block, required: true

  def save_bar(assigns) do
    ~H"""
    <div class="sticky bottom-0 z-10 flex items-center justify-end gap-2 rounded-2xl border border-base-300 bg-surface/90 p-4 shadow-sm backdrop-blur dark:bg-base-100/90">
      <.unsaved_note dirty={@dirty} id={@note_id} />
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, default: "unsaved-changes-dialog"
  attr :message, :string, default: "You have unsaved changes. Save them before you leave?"

  def unsaved_changes_dialog(assigns) do
    ~H"""
    <dialog id={@id} class="modal" phx-update="ignore">
      <div class="modal-box max-w-md">
        <h3 class="text-lg font-semibold">Save your changes?</h3>
        <p class="py-2 text-sm text-base-content/70">{@message}</p>
        <div class="modal-action">
          <button type="button" class="btn btn-ghost" data-unsaved-action="stay">
            Keep editing
          </button>
          <button type="button" class="btn btn-ghost text-error" data-unsaved-action="discard">
            Discard
          </button>
          <button type="button" class="btn btn-primary" data-unsaved-action="save">Save</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end

  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search"
  attr :on_change, :string, default: "search"
  attr :on_clear, :string, default: "clear_search"
  attr :name, :string, default: "query"
  attr :class, :any, default: "w-full sm:max-w-sm"
  attr :rest, :global

  def search_field(assigns) do
    ~H"""
    <form phx-change={@on_change} phx-submit={@on_change} class={@class} {@rest}>
      <label class="input w-full">
        <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
        <input
          type="search"
          name={@name}
          value={@value}
          placeholder={@placeholder}
          phx-debounce="300"
          autocomplete="off"
          class="grow"
        />
        <button
          :if={@value not in [nil, ""]}
          type="button"
          phx-click={@on_clear}
          class="btn btn-ghost btn-xs btn-circle"
          aria-label="Clear search"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </label>
    </form>
    """
  end

  @doc """
  A table styled for the panel look. Same slots as the core `table`; set
  `class` on a `:col` to size or align it.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :row_click, :any, default: nil
  attr :row_class, :any, default: nil
  attr :row_item, :any, default: &Function.identity/1

  slot :col, required: true do
    attr :label, :string
    attr :class, :any
  end

  slot :action

  def data_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
          <tr>
            <th :for={col <- @col} class={["px-6 py-3 font-medium", col[:class]]}>{col[:label]}</th>
            <th :if={@action != []} class="px-6 py-3"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-base-300"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={["transition-colors hover:bg-base-200/40", @row_class && @row_class.(row)]}
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-6 py-3 align-middle", col[:class], @row_click && "cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 px-6 py-3">
              <div class="flex items-center justify-end gap-1">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  A square ghost icon button for row actions. Pass `navigate`, `patch`, `href`
  or `phx-click` as you would to `link`.
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :tone, :string, default: "neutral", values: ~w(neutral error)
  attr :rest, :global, include: ~w(navigate patch href method replace download)

  def icon_button(assigns) do
    ~H"""
    <.link
      class={[
        "btn btn-ghost btn-sm btn-square",
        @tone == "error" && "text-error"
      ]}
      title={@label}
      aria-label={@label}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil
  slot :inner_block, doc: "rich content; overrides `value`"

  def detail_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-xs text-base-content/50">{@label}</dt>
      <dd class="mt-0.5 break-words text-sm">
        <%= cond do %>
          <% @inner_block != [] -> %>
            {render_slot(@inner_block)}
          <% @value in [nil, ""] -> %>
            <span class="text-base-content/40">-</span>
          <% true -> %>
            {@value}
        <% end %>
      </dd>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :open, :boolean, required: true
  attr :toggle, :string, required: true
  slot :inner_block, required: true

  def archived_section(assigns) do
    ~H"""
    <section :if={@count > 0} class="mt-8">
      <button
        type="button"
        phx-click={@toggle}
        aria-expanded={to_string(@open)}
        class="flex items-center gap-2 text-sm font-medium text-base-content/60 hover:text-base-content"
      >
        <.icon
          name="hero-chevron-right"
          class={
            if @open, do: "size-4 rotate-90 transition-transform", else: "size-4 transition-transform"
          }
        />
        {@label}
        <span class="rounded-full bg-base-200 px-2 py-0.5 text-xs">{@count}</span>
      </button>
      <div :if={@open} class="mt-3">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def chip(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-md border border-base-300 bg-base-200 px-2 py-0.5 text-xs text-base-content/80",
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :tone, :string, default: "neutral", values: ~w(neutral success warning info error)
  slot :inner_block, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium",
      tone_class(@tone)
    ]}>
      <span class="size-1.5 rounded-full bg-current" aria-hidden="true"></span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp tone_class("neutral"), do: "bg-base-200 text-base-content/70"
  defp tone_class("success"), do: "bg-success/15 text-success"
  defp tone_class("warning"), do: "bg-warning/15 text-warning"
  defp tone_class("info"), do: "bg-info/15 text-info"
  defp tone_class("error"), do: "bg-error/15 text-error"

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :hint, :string, default: nil
  attr :value_class, :any, default: nil
  slot :inner_block, required: true

  def stat_tile(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-200/40 px-4 py-3">
      <div class="flex items-center justify-between gap-2 text-xs text-base-content/60">
        <span>{@label}</span>
        <.icon name={@icon} class="size-4 text-base-content/40" />
      </div>
      <div class={["mt-1 text-xl font-semibold", @value_class]}>{render_slot(@inner_block)}</div>
      <div :if={@hint} class="text-xs text-base-content/50">{@hint}</div>
    </div>
    """
  end

  attr :class, :any, default: "size-5"

  def bullseye_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 20 20" fill="none" stroke="currentColor" aria-hidden="true">
      <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
      <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
      <circle cx="10" cy="10" r="2.5" fill="currentColor" />
    </svg>
    """
  end

  @doc """
  Returns `path` when it is a local path, otherwise `default`. Guards the
  `return_to` param the unsaved-changes dialog adds when saving before leaving.
  """
  def safe_return_to("/" <> rest = path, default) do
    if String.starts_with?(rest, ["/", "\\"]), do: default, else: path
  end

  def safe_return_to(_path, default), do: default
end
