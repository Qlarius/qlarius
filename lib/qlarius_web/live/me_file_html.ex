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

  def tag_edit_modal(assigns) do
    ~H"""
    <dialog id="tag_edit_modal" phx-hook="Modal" class="modal modal-bottom sm:modal-middle !overflow-y-hidden">
      <div class="flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0">
      <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content">
        <h3 class="text-lg font-bold">{if @trait_in_edit, do: @trait_in_edit.trait_name, else: "Edit Trait"}</h3>
        <form method="dialog">
          <button class="btn btn-md btn-circle btn-ghost">✕</button>
        </form>
        </div>
        <div class="flex-grow p-4 bg-base-200 text-base-content/70">
          <p :if={@trait_in_edit && @trait_in_edit.survey_question} class="whitespace-pre-line">{Phoenix.HTML.raw(@trait_in_edit.survey_question.text)}</p>
          </div>
          <div :if={@trait_in_edit && @trait_in_edit.child_traits} class="p-4 overflow-auto">
          <div :for={child_trait <- Enum.sort_by(@trait_in_edit.child_traits, & &1.display_order)} class="flex items-center gap-2 [&:not(:last-child)]:border-b border-dashed border-base-content/10">
            <div :if={child_trait.survey_answer} class="p-3 text-md text-base-content">
              {child_trait.survey_answer.text}
            </div>
          </div>
        </div>
        <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 text-base-content/70">
          <button class="btn btn-md btn-ghost">Cancel</button>
          <button class="btn btn-md btn-primary">Save/Update Tags</button>
        </div>

        <%!-- <pre :if={@trait_in_edit} class="py-4 overflow-auto max-h-96 whitespace-pre-wrap bg-base-200 rounded-lg p-4">{inspect(@trait_in_edit, pretty: true, width: 60)}</pre> --%>
      </div>
    </dialog>
    """
  end
end
