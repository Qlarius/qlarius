defmodule QlariusWeb.Components.TraitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  attr :parent_trait_id, :integer, required: true
  attr :parent_trait_name, :string, required: true
  attr :tags_traits, :list, required: true
  attr :extra_classes, :string, default: ""
  attr :clickable, :boolean, default: false
  attr :editable, :boolean, default: true

  def trait_card(assigns) do
    ~H"""
    <div
      id={"trait-card-#{@parent_trait_id}"}
      phx-hook="AnimateTrait"
      class={[
        "h-full border rounded-lg bg-base-100 transition-all duration-300 ease-in-out",
        @tags_traits == [] &&
          "border-2 empty-trait-strobe border-youdata-500 dark:border-base-content",
        @tags_traits != [] && "border-youdata-300 dark:border-youdata-500",
        @clickable && @editable && @tags_traits == [] &&
          @parent_trait_name not in ["Birthdate", "Age", "Sex (Bio)"] &&
          "cursor-pointer",
        @extra_classes
      ]}
      phx-click={
        @clickable && @editable && @tags_traits == [] &&
          @parent_trait_name not in ["Birthdate", "Age", "Sex (Bio)"] &&
          "edit_tags"
      }
      phx-value-id={
        @clickable && @editable && @tags_traits == [] &&
          @parent_trait_name not in ["Birthdate", "Age", "Sex (Bio)"] &&
          @parent_trait_id
      }
    >
      <div class="overflow-hidden rounded-lg">
        <div class="bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content px-4 py-2 text-lg font-bold flex justify-between items-center">
          <span>{@parent_trait_name}</span>
          <div
            :if={@editable && @parent_trait_name not in ["Birthdate", "Age", "Sex (Bio)"]}
            class="ms-4 flex gap-3"
          >
            <button
              class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
              phx-click="edit_tags"
              phx-value-id={@parent_trait_id}
            >
              <.icon name="hero-pencil" class="h-5 w-5" />
            </button>
            <button
              class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
              phx-click="delete_tags"
              phx-value-id={@parent_trait_id}
            >
              <.icon name="hero-trash" class="h-5 w-5" />
            </button>
          </div>
        </div>
        <div class={[
          "p-0 space-y-1 max-h-[245px] overflow-y-auto",
          @tags_traits == [] && "bg-warning/30"
        ]}>
          <div
            :for={{tag_id, tag_value, _display_order} <- @tags_traits}
            class="mx-0 my-2 text-lg [&:not(:last-child)]:border-b border-dashed border-base-content/20"
          >
            <div class="px-4 py-1">{tag_value}</div>
          </div>
          <div :if={@tags_traits == []} class="mx-0 my-2 text-lg">
            <div class="px-4 py-1 italic test-base-content">
              <%= if function_exported?(Qlarius.YouData.TagTeaseAgent, :next_message, 0) do %>
                {Qlarius.YouData.TagTeaseAgent.next_message()}
              <% else %>
                Click to add tags
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
