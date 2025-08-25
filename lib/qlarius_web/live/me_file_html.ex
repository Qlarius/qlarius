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
    <dialog id="tag_edit_modal" phx-hook="Modal" class="modal modal-bottom sm:modal-middle">
      <div class="modal-box">
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
        </form>
        <h3 class="text-lg font-bold">{if @trait_in_edit, do: @trait_in_edit.trait_name, else: "Edit Trait"}</h3>
        <p class="py-4">Press ESC key or click the button above to close</p>
      </div>
    </dialog>
    """
  end
end
