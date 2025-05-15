defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <.header>View content</.header>

      <iframe
        width="560"
        height="315"
        src="https://www.youtube.com/embed/dQw4w9WgXcQ?si=o58dkCtLdJpHYGW0"
        title="YouTube video player"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
      >
      </iframe>

      <.back navigate={~p"/widgets/arcade/group/#{@content.content_group.id}"}>Back to arcade</.back>
    </div>
    """
  end
end
