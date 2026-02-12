defmodule QlariusWeb.TiqitClassHTML do
  use QlariusWeb, :html

  import QlariusWeb.Money, only: [format_usd: 1, format_usd: 2]

  attr :form, Phoenix.HTML.Form, required: true

  def inputs_for_tiqit_classes(assigns) do
    ~H"""
    <.inputs_for :let={tcf} field={@form[:tiqit_classes]}>
      <input type="hidden" name={"#{@form.name}[tiqit_class_sort][]"} value={tcf.index} />

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
        <div class="form-control">
          <label class="label">
            <span class="label-text font-medium">Duration (hours)</span>
          </label>
          <.input
            field={tcf[:duration_hours]}
            type="number"
            class="input input-bordered w-full"
            placeholder="Enter duration in hours"
          />
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text font-medium">Price ($)</span>
          </label>
          <.input
            field={tcf[:price]}
            type="text"
            class="input input-bordered w-full"
            placeholder="Enter price"
          />
        </div>

        <div class="form-control">
          <button
            type="button"
            name={"#{@form.name}[tiqit_class_drop][]"}
            value={tcf.index}
            phx-click={JS.dispatch("change")}
            class="btn btn-outline btn-error btn-sm"
            aria-label="Remove tiqit class"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </.inputs_for>

    <div class="mt-6 pt-4 border-t border-base-300">
      <button
        class="btn btn-outline btn-sm"
        name={"#{@form.name}[tiqit_class_sort][]"}
        phx-click={JS.dispatch("change")}
        type="button"
        value="new"
      >
        <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Add Tiqit Class
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

  # record is a Catalog, ContentGroup or ContentPiece with preloaded tiqit_classes
  attr :record, :any, required: true

  def tiqit_classes_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full">
        <thead class="bg-base-200">
          <tr>
            <th class="font-semibold text-base-content text-left">Duration</th>
            <th class="font-semibold text-base-content text-left">Price</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-base-300">
          <%= for tc <- Enum.sort_by(@record.tiqit_classes, &(&1.duration_hours || 999_999)) do %>
            <tr class="hover:bg-base-200 transition-colors">
              <td class="font-medium text-base-content">
                <div class="badge badge-outline badge-sm">
                  {format_tiqit_class_duration(tc.duration_hours)}
                </div>
              </td>
              <td class="text-base-content">
                <span class="badge badge-primary badge-sm">
                  <.icon name="hero-currency-dollar" class="w-3 h-3 mr-1" />
                  {format_usd(tc.price, zero_free: true)}
                </span>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
