defmodule QlariusWeb.ContentHTML do
  use QlariusWeb, :html

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
