defmodule QlariusWeb.MeFileHTML do
  use QlariusWeb, :html

  # embed_templates "me_file_html/*"

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
      <div class="bg-youdata-500 text-white px-3 py-1 rounded-full text-sm border-gray-300">
        {@trait_count} traits
      </div>
      <div class="bg-base-100 text-base-content px-3 py-1 rounded-full text-sm border-base-300">
        {@tag_count} tags
      </div>
    </div>
    """
  end
end
