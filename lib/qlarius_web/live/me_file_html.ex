defmodule QlariusWeb.MeFileHTML do
  use QlariusWeb, :html

  embed_templates "me_file_html/*"

  def progress_bar_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500"
      percentage > 0 -> "bg-orange-500"
      true -> "bg-red-500"
    end
  end

  def badge_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500 text-white"
      percentage > 0 -> "bg-orange-500 text-white"
      true -> "bg-red-500 text-white"
    end
  end

  attr :tag_count, :integer, required: true
  attr :trait_count, :integer, required: true

  def tag_and_trait_count_badges(assigns) do
    ~H"""
    <div class="flex gap-4 mb-6">
      <div class="bg-youdata-300 dark:bg-youdata-800 text-base-content px-3 py-1 rounded-full text-sm border border-youdata-500">
        {@trait_count} traits
      </div>
      <div class="bg-base-100 text-base-content px-3 py-1 rounded-full text-sm border border-neutral-300 dark:border-neutral-500">
        {@tag_count} tags
      </div>
    </div>
    """
  end

  attr :trait_in_edit, :any, default: nil
  attr :me_file_id, :integer, required: true
  attr :selected_ids, :list, default: []
  attr :show_modal, :boolean, default: false

  def tag_edit_modal(assigns) do
    ~H"""
    <div class={["modal modal-bottom sm:modal-middle", @show_modal && "modal-open"]}>
      <div class="flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0 max-h-[90vh]">
        <%!-- Fixed header --%>
        <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content shrink-0">
          <h3 class="text-lg font-bold">
            {if @trait_in_edit, do: @trait_in_edit.trait_name, else: "Edit Trait"}
          </h3>
          <button type="button" phx-click="close_modal" class="btn btn-md btn-circle btn-ghost">✕</button>
        </div>

        <%!-- Fixed question section --%>
        <div class="p-4 bg-base-200 text-base-content/70 shrink-0">
          <p :if={@trait_in_edit && @trait_in_edit.survey_question}>
            {Phoenix.HTML.raw(@trait_in_edit.survey_question.text)}
          </p>
        </div>

        <%!-- Expandable content area --%>
        <.form
          :if={@trait_in_edit}
          for={%{}}
          phx-submit="save_tags"
          class="flex flex-col flex-1 min-h-0"
        >
          <div class="flex-1 overflow-y-auto p-4">
            <input type="hidden" name="me_file_id" value={@me_file_id} />
            <input type="hidden" name="trait_id" value={@trait_in_edit.id} />
            <div :if={@trait_in_edit.child_traits} class="py-0">
              <label
                :for={child_trait <- Enum.sort_by(@trait_in_edit.child_traits, & &1.display_order)}
                class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 py-3 px-2 hover:bg-base-200 cursor-pointer"
              >
                <input
                  :if={@trait_in_edit.input_type == "SingleSelect"}
                  type="radio"
                  name="child_trait_ids[]"
                  value={child_trait.id}
                  id={"trait-#{child_trait.id}"}
                  checked={child_trait.id in @selected_ids}
                  class="radio w-7 h-7"
                />
                <input
                  :if={@trait_in_edit.input_type == "MultiSelect"}
                  type="checkbox"
                  name="child_trait_ids[]"
                  value={child_trait.id}
                  id={"trait-#{child_trait.id}"}
                  checked={child_trait.id in @selected_ids}
                  class="checkbox w-7 h-7"
                />
                <div class="text-md text-base-content">
                  {if child_trait.survey_answer && child_trait.survey_answer.text not in [nil, ""],
                     do: child_trait.survey_answer.text,
                     else: child_trait.trait_name}
                </div>
              </label>
            </div>
          </div>

          <%!-- Fixed footer --%>
          <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
            <button type="button" phx-click="close_modal" class="btn btn-md btn-ghost">Cancel</button>
            <button type="submit" class="btn btn-md btn-primary">Save/Update Tags</button>
          </div>
        </.form>
      </div>
      <%!-- <pre :if={@trait_in_edit} class="py-4 overflow-auto max-h-96 whitespace-pre-wrap bg-base-200 rounded-lg p-4">{inspect(@trait_in_edit, pretty: true, width: 60)}</pre> --%>
    </div>
    """
  end
end
