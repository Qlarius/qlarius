defmodule QlariusWeb.Components.TraitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  attr :parent_trait_id, :integer, required: true
  attr :parent_trait_name, :string, required: true
  attr :tags_traits, :list, default: []
  attr :extra_classes, :string, default: ""
  attr :clickable, :boolean, default: false
  attr :editable, :boolean, default: true
  attr :display_mode, :string, default: "tag"

  @protected_traits ["Birthdate", "Age", "Sex (Bio)"]

  attr :actions_class, :string, default: "ms-4 flex gap-3 shrink-0"

  def trait_actions(assigns) do
    assigns =
      assigns
      |> assign_new(:editable, fn -> true end)
      |> assign_new(:actions_class, fn -> "ms-4 flex gap-3 shrink-0" end)

    ~H"""
    <div
      :if={@editable && !protected_trait_name?(@parent_trait_name)}
      class={@actions_class}
    >
      <button
        type="button"
        class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
        phx-click="edit_tags"
        phx-value-id={@parent_trait_id}
      >
        <.icon name="hero-pencil" class="h-5 w-5" />
      </button>
      <button
        type="button"
        class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
        phx-click="delete_tags"
        phx-value-id={@parent_trait_id}
      >
        <.icon name="hero-trash" class="h-5 w-5" />
      </button>
    </div>
    """
  end

  def trait_card(assigns) do
    assigns =
      assigns
      |> assign_new(:extra_classes, fn -> "" end)
      |> assign_new(:clickable, fn -> false end)
      |> assign_new(:editable, fn -> true end)
      |> assign_new(:display_mode, fn -> "tag" end)
      |> assign_new(:tags_traits, fn -> [] end)
      |> assign(:random_delay, :rand.uniform(2000))
      |> assign(:block_mode?, assigns.display_mode == "block")

    ~H"""
    <div
      id={"trait-card-#{@parent_trait_id}"}
      phx-hook="AnimateTrait"
      class={[
        "border rounded-lg bg-base-100 transition-all duration-300 ease-in-out",
        @block_mode? && "h-full flex flex-col",
        !@block_mode? && "h-full",
        @tags_traits == [] &&
          "border-2 empty-trait-strobe border-youdata-500 dark:border-base-content",
        @tags_traits != [] && "border-youdata-500",
        @clickable && @editable && @tags_traits == [] &&
          !protected_trait_name?(@parent_trait_name) &&
          "cursor-pointer",
        @extra_classes
      ]}
      style={@tags_traits == [] && "--animation-delay: #{@random_delay}ms"}
      phx-click={
        @clickable && @editable && @tags_traits == [] &&
          !protected_trait_name?(@parent_trait_name) &&
          "edit_tags"
      }
      phx-value-id={
        @clickable && @editable && @tags_traits == [] &&
          !protected_trait_name?(@parent_trait_name) &&
          @parent_trait_id
      }
    >
      <div class={["overflow-hidden rounded-lg", @block_mode? && "flex flex-col flex-1 min-h-0"]}>
        <div class="bg-base-300/50 dark:bg-base-700/45 border-t-2 border-youdata-500 text-base-content px-4 py-3 text-lg font-bold leading-tight flex justify-between items-center shrink-0">
          <span class="min-w-0 text-youdata-800 dark:text-youdata-200">{@parent_trait_name}</span>
          <.trait_actions
            parent_trait_id={@parent_trait_id}
            parent_trait_name={@parent_trait_name}
            editable={@editable}
          />
        </div>
        <div class={[
          "p-0 max-h-[245px] overflow-y-auto",
          @block_mode? && @tags_traits != [] && "flex flex-1 flex-col min-h-0",
          !@block_mode? && "space-y-1",
          @tags_traits == [] && "bg-warning/30"
        ]}>
          <div :if={@block_mode? && @tags_traits != []} class="shrink-0">
            <div
              :for={{_tag_id, tag_value, _display_order} <- @tags_traits}
              class="mx-0 my-1 text-lg leading-tight [&:not(:last-child)]:border-b border-dashed border-base-content/20"
            >
              <div class="px-4 py-0.5 leading-tight">{tag_value}</div>
            </div>
          </div>
          <div
            :if={@block_mode? && @tags_traits != []}
            class="flex-1 min-h-6 bg-base-200/60 dark:bg-base-300/25"
            aria-hidden="true"
          />
          <div
            :if={!@block_mode?}
            :for={{_tag_id, tag_value, _display_order} <- @tags_traits}
            class="mx-0 my-1 text-lg leading-tight [&:not(:last-child)]:border-b border-dashed border-base-content/20"
          >
            <div class="px-4 py-0.5 leading-tight">{tag_value}</div>
          </div>
          <div :if={@tags_traits == []} class="mx-0 my-1 text-lg leading-tight">
            <div class="px-4 py-0.5 italic test-base-content leading-tight">
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

  def protected_trait_name?(name), do: name in @protected_traits
end
