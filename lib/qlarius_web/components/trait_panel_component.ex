defmodule QlariusWeb.TraitPanelComponent do
  use QlariusWeb, :html

  attr :trait, :map, required: true
  attr :disabled, :boolean, default: true
  attr :on_submit, :any, default: nil
  attr :selected_values, :list, default: []

  def trait_panel(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-4 shadow-sm">
      <div class="flex justify-between items-center mb-2">
        <h3 class="text-lg font-medium">{@trait.name}</h3>
      </div>

      <%= if @trait.question do %>
        <p class="text-gray-600 mb-3">{@trait.question}</p>
      <% end %>

      <.form :if={@on_submit} for={%{}} phx-submit={@on_submit} phx-value-trait-id={@trait.id}>
        <div class="space-y-2">
          <%= for value <- @trait.values do %>
            <div class="flex items-center gap-2">
              <label class="flex items-center gap-2 cursor-pointer w-full">
                <%= if @trait.input_type == :checkboxes do %>
                  <input
                    type="checkbox"
                    name="values[]"
                    value={value.id}
                    id={"value-#{value.id}"}
                    checked={value.id in @selected_values}
                    disabled={@disabled}
                    class="rounded border-gray-300"
                  />
                <% else %>
                  <input
                    type="radio"
                    name="value"
                    value={value.id}
                    id={"value-#{value.id}"}
                    checked={value.id in @selected_values}
                    disabled={@disabled}
                    class="rounded-full border-gray-300"
                  />
                <% end %>
                <span class="text-gray-700 select-none">
                  {value.answer || value.name}
                </span>
              </label>
            </div>
          <% end %>
        </div>
        <div :if={@on_submit} class="mt-4 flex justify-end">
          <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
            Save & Continue
          </button>
        </div>
      </.form>

      <div :if={!@on_submit} class="space-y-2">
        <%= for value <- @trait.values do %>
          <div class="flex items-center gap-2">
            <label class="flex items-center gap-2 w-full">
              <%= if @trait.input_type == :checkboxes do %>
                <input type="checkbox" disabled class="rounded border-gray-300" />
              <% else %>
                <input type="radio" disabled class="rounded-full border-gray-300" />
              <% end %>
              <span class="text-gray-700 select-none">
                {value.answer || value.name}
              </span>
            </label>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
