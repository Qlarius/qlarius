defmodule QlariusWeb.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    # TODO 'back' should go to the right group for the content
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
    </div>
    """
  end

  def groups(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <div class="flex flex-col gap-4">
        <.header>Content groups</.header>

        <ul class="list-disc">
          <li :for={group <- @groups}>
            <.link navigate={~p"/arcade/group/#{group}"}>{group.title}</.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
