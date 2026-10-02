defmodule QlariusWeb.TiqitClassHTML do
  use QlariusWeb, :html

  alias Qlarius.Tiqit.Arcade.TiqitClass
  import QlariusWeb.Money, only: [format_usd: 2]

  attr :form, Phoenix.HTML.Form, required: true

  def inputs_for_tiqit_classes(assigns) do
    ~H"""
    <div class="space-y-1">
      <div
        :if={@form[:tiqit_classes].value not in [nil, []]}
        class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2.5rem] gap-3 px-1 text-xs font-medium text-base-content/60"
      >
        <span>Duration (hours)</span>
        <span>Price ($)</span>
        <span class="sr-only">Remove</span>
      </div>

      <.inputs_for :let={tcf} field={@form[:tiqit_classes]}>
        <input type="hidden" name={"#{@form.name}[tiqit_class_sort][]"} value={tcf.index} />

        <div class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2.5rem] items-start gap-3">
          <.input
            field={tcf[:duration_hours]}
            type="number"
            min="1"
            placeholder="e.g. 24"
            aria-label="Duration in hours"
          />
          <.input
            field={tcf[:price]}
            type="text"
            inputmode="decimal"
            placeholder="e.g. 0.75"
            aria-label="Price in dollars"
          />
          <button
            type="button"
            name={"#{@form.name}[tiqit_class_drop][]"}
            value={tcf.index}
            phx-click={JS.dispatch("change")}
            class="btn btn-ghost btn-sm btn-square mt-1 text-error"
            aria-label="Remove tiqit class"
            title="Remove"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </.inputs_for>

      <button
        class="btn btn-ghost btn-sm mt-2"
        name={"#{@form.name}[tiqit_class_sort][]"}
        phx-click={JS.dispatch("change")}
        type="button"
        value="new"
      >
        <.icon name="hero-plus" class="size-4" /> Add tiqit class
      </button>
    </div>
    """
  end

  # Returns duration as:
  # - "Lifetime" is duration is nil
  # - "X weeks" if evenly divisible by 7 days (168 hours)
  # - "X days" if evenly divisible by 24 hours (exception: "24 hours" not "1 day")
  # - "X hours" otherwise
  # Examples: "2 weeks", "3 days", "26 hours"
  def format_tiqit_class_duration(hours) do
    cond do
      is_nil(hours) ->
        "Lifetime"

      rem(hours, 24 * 7) == 0 ->
        "#{div(hours, 24 * 7)} week#{if div(hours, 24 * 7) > 1, do: "s"}"

      rem(hours, 24) == 0 and hours != 24 ->
        "#{div(hours, 24)} day#{if div(hours, 24) > 1, do: "s"}"

      true ->
        "#{hours} hour#{if hours > 1, do: "s"}"
    end
  end

  attr :record, :any, required: true
  attr :on_delete, :string, default: nil

  def tiqit_classes_table(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300">
      <li
        :for={tc <- TiqitClass.order_by_duration_hours_asc(@record.tiqit_classes)}
        class="flex items-center gap-3 px-6 py-2.5 text-sm"
      >
        <span class="flex min-w-0 flex-1 items-center gap-2 text-base-content/80">
          <.icon name="hero-clock" class="size-4 shrink-0 text-base-content/40" />
          {format_tiqit_class_duration(tc.duration_hours)}
        </span>
        <span class="font-semibold">{format_usd(tc.price, zero_free: true)}</span>
        <button
          :if={@on_delete}
          type="button"
          phx-click={@on_delete}
          phx-value-id={tc.id}
          data-confirm="Delete this tiqit class?"
          class="btn btn-ghost btn-xs btn-square text-error"
          aria-label="Delete tiqit class"
          title="Delete"
        >
          <.icon name="hero-trash" class="size-3.5" />
        </button>
      </li>
    </ul>
    """
  end

  attr :tiqit_classes, :list, required: true
  attr :empty_label, :string, default: "No pricing"

  def price_chips(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-1">
      <span
        :if={@tiqit_classes == []}
        class="inline-flex items-center gap-1 rounded-full bg-warning/15 px-2 py-0.5 text-xs font-medium text-warning"
      >
        <.icon name="hero-exclamation-triangle" class="size-3" /> {@empty_label}
      </span>
      <span
        :for={tc <- TiqitClass.order_by_duration_hours_asc(@tiqit_classes)}
        class="rounded-md border border-base-300 bg-base-200/50 px-1.5 py-0.5 text-xs text-base-content/70"
      >
        {format_tiqit_class_duration(tc.duration_hours)} · {format_usd(tc.price, zero_free: true)}
      </span>
    </div>
    """
  end
end
