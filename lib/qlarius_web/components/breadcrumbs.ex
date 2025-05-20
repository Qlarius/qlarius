defmodule QlariusWeb.Components.Breadcrumbs do
  use QlariusWeb, :html

  alias Phoenix.LiveView.JS
  import QlariusWeb.CoreComponents

  attr :crumbs, :list, required: true, doc: "List of {text, href} tuples for breadcrumb items"

  def breadcrumbs(assigns) do
    ~H"""
    <nav class="flex" aria-label="Breadcrumb">
      <ol class="inline-flex flex-wrap items-center space-x-1 md:space-x-2 gap-y-2">
        <li class="inline-flex items-center">
          <.link
            navigate={~p"/creators"}
            class="inline-flex items-center text-sm font-medium text-gray-700 hover:text-orange-600"
          >
            <.icon name="hero-home-mini" class="w-3 h-3 me-2.5" /> Creators
          </.link>
        </li>
        <li :for={{text, href} <- @crumbs}>
          <div class="flex items-center">
            <.icon name="hero-chevron-right-mini" class="h-3 w-3 text-gray-400 mx-1" />
            <.link
              navigate={href}
              class="ms-1 text-sm font-medium text-gray-700 hover:text-orange-600 md:ms-2 whitespace-nowrap utility"
            >
              {text}
            </.link>
          </div>
        </li>
      </ol>
    </nav>
    """
  end
end
