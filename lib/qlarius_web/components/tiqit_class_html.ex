defmodule QlariusWeb.TiqitClassHTML do
  use QlariusWeb, :html

  alias Qlarius.Arcade.TiqitClass

  import QlariusWeb.Money, only: [format_usd: 1]

  attr :form, Phoenix.HTML.Form, required: true

  def inputs_for_tiqit_classes(assigns) do
    ~H"""
    <.inputs_for :let={tcf} field={@form[:tiqit_classes]}>
      <input type="hidden" name={"#{@form.name}[tiqit_class_sort][]"} value={tcf.index} />

      <div class="flex align-start gap-4">
        <.input field={tcf[:duration_hours]} type="number" label="Duration (hours)" />
        <.input field={tcf[:price]} type="text" label="Price ($)" />

        <button
          type="button"
          name={"#{@form.name}[tiqit_class_drop][]"}
          value={tcf.index}
          phx-click={JS.dispatch("change")}
          class="relative top-4"
        >
          <.icon name="hero-x-mark" class="w-6 h-6" />
        </button>
      </div>
    </.inputs_for>

    <button
      class="my-4 text-zinc-700"
      name={"#{@form.name}[tiqit_class_sort][]"}
      phx-click={JS.dispatch("change")}
      type="button"
      value="new"
    >
      <.icon name="hero-plus-circle" class="h-5 w-5 relative top-[-1px]" /> Add Tiqit class
    </button>
    """
  end

  # Returns duration as:
  # - "X weeks" if evenly divisible by 7 days (168 hours)
  # - "X days" if evenly divisible by 24 hours (exception: "24 hours" not "1 day")
  # - "X hours" otherwise
  # Examples: "2 weeks", "3 days", "26 hours"
  def tiqit_class_duration(%TiqitClass{} = tc) do
    if tc.duration_hours do
      format_tiqit_class_duration(tc.duration_hours)
    else
      "Lifetime"
    end
  end

  def format_tiqit_class_duration(hours) do
    cond do
      rem(hours, 24 * 7) == 0 ->
        "#{div(hours, 24 * 7)} week#{if div(hours, 24 * 7) > 1, do: "s"}"

      rem(hours, 24) == 0 and hours != 24 ->
        "#{div(hours, 24)} day#{if div(hours, 24) > 1, do: "s"}"

      true ->
        "#{hours} hour#{if hours > 1, do: "s"}"
    end
  end

  # record is a Catalog, ContentGroup or ContentPiece with preloaded tiqit_classes
  attr :record, :any, required: true

  def tiqit_classes_table(assigns) do
    ~H"""
    <.table id="catalog_tiqit_classes" rows={@record.tiqit_classes} zebra={false}>
      <:col :let={tc} label="Duration">{tiqit_class_duration(tc)}</:col>
      <:col :let={tc} label="Price">{format_usd(tc.price)}</:col>
    </.table>
    """
  end
end
