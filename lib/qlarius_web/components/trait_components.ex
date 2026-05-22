defmodule QlariusWeb.Components.TraitComponents do
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  attr :parent_trait_id, :integer, required: true
  attr :parent_trait_name, :string, required: true
  attr :tags_traits, :list, default: []
  attr :extra_classes, :string, default: ""
  attr :clickable, :boolean, default: false
  attr :editable, :boolean, default: true
  attr :nav_indicator, :string, default: "edit", values: ["edit", "chevron", "none"]
  attr :display_mode, :string, default: "tag"

  @protected_traits ["Birthdate", "Age", "Sex (Bio)"]

  attr :actions_class, :string, default: "ms-4 flex gap-3 shrink-0"

  def trait_actions(assigns) do
    assigns =
      assigns
      |> assign_new(:editable, fn -> true end)
      |> assign_new(:actions_class, fn -> "ms-4 flex gap-3 shrink-0" end)
      |> assign_new(:nav_indicator, fn -> "edit" end)

    ~H"""
    <div
      :if={@editable && !protected_trait_name?(@parent_trait_name) && @nav_indicator != "none"}
      class={@actions_class}
    >
      <%= if @nav_indicator == "chevron" do %>
        <span class="text-base-content/30 pointer-events-none" aria-hidden="true">
          <.icon name="hero-chevron-right" class="h-5 w-5" />
        </span>
      <% else %>
        <button
          type="button"
          class="text-base-content/20 hover:text-base-content/80 cursor-pointer"
          phx-click="edit_tags"
          phx-value-id={@parent_trait_id}
          aria-label={"Edit #{@parent_trait_name}"}
        >
          <.icon name="hero-pencil" class="h-5 w-5" />
        </button>
      <% end %>
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
      |> assign_new(:nav_indicator, fn -> "edit" end)
      |> assign_new(:tags_traits, fn -> [] end)
      |> assign(:strobe_delay_ms, rem(abs(assigns.parent_trait_id), 2000))
      |> then(fn a ->
        a
        |> assign(:block_mode?, a.display_mode == "block")
        |> assign(
          :tap_to_edit?,
          a.clickable && a.editable && !protected_trait_name?(a.parent_trait_name)
        )
      end)

    ~H"""
    <div
      id={"trait-card-#{@parent_trait_id}"}
      class={[
        "trait-card-animate border rounded-lg bg-base-100 transition-shadow duration-300 ease-in-out",
        @block_mode? && "h-full flex flex-col",
        !@block_mode? && "h-full",
        "border-youdata-500",
        @tap_to_edit? && "cursor-pointer hover:shadow-md hover:z-10 relative",
        @extra_classes
      ]}
      phx-click={@tap_to_edit? && "edit_tags"}
      phx-value-id={@tap_to_edit? && @parent_trait_id}
    >
      <div class={["overflow-hidden rounded-lg", @block_mode? && "flex flex-col flex-1 min-h-0"]}>
        <div
          class={[
            "border-t-2 border-youdata-500 text-base-content px-4 py-3 text-lg font-bold leading-tight flex justify-between items-center shrink-0",
            "bg-base-300/50 dark:bg-base-700/45",
            @tags_traits == [] && "empty-trait-header-strobe"
          ]}
          style={@tags_traits == [] && "--animation-delay: #{@strobe_delay_ms}ms"}
        >
          <span class={[
            "min-w-0 font-bold leading-tight",
            @tags_traits == [] && "text-base-content/65 dark:text-base-content/75",
            @tags_traits != [] && "text-youdata-800 dark:text-youdata-200"
          ]}>
            {@parent_trait_name}
          </span>
          <.trait_actions
            parent_trait_id={@parent_trait_id}
            parent_trait_name={@parent_trait_name}
            editable={@editable}
            nav_indicator={@nav_indicator}
          />
        </div>
        <div class={[
          "p-0 max-h-[245px] overflow-y-auto",
          @block_mode? && @tags_traits != [] && "flex flex-1 flex-col min-h-0",
          !@block_mode? && "space-y-1"
        ]}>
          <div :if={@block_mode? && @tags_traits != []} class="shrink-0">
            <div
              :for={{_tag_id, tag_value, _display_order} <- @tags_traits}
              class="mx-0 my-1 text-base leading-tight text-base-content/80 [&:not(:last-child)]:border-b border-dashed border-base-content/20"
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
            class="mx-0 my-1 text-base leading-tight text-base-content/80 [&:not(:last-child)]:border-b border-dashed border-base-content/20"
          >
            <div class="px-4 py-0.5 leading-tight">{tag_value}</div>
          </div>
          <div :if={@tags_traits == []} class="mx-0 my-1 text-base leading-tight">
            <div class="px-4 py-0.5 italic text-base-content/40 leading-tight">
              {empty_tag_tease_message()}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def protected_trait_name?(name), do: name in @protected_traits

  @doc """
  Returns the next tag tease prompt from `TagTeaseAgent` (non-repeating pool).
  """
  def empty_tag_tease_message do
    Qlarius.YouData.TagTeaseAgent.next_message()
  end
end
