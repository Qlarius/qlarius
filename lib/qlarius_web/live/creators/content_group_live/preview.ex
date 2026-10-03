defmodule QlariusWeb.Creators.ContentGroupLive.Preview do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Creators
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    group = Creators.get_content_group!(id)

    {:ok,
     socket
     |> assign(:group, group)
     |> assign(:catalog, group.catalog)
     |> assign(:creator, group.catalog.creator)
     |> assign(:page_title, "Arcade Preview")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp content_group_iframe_url(group) do
    Qlarius.Qlink.Urls.public_app_url("/widgets/arqade/group/#{group.id}")
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :group_word,
        Catalog.type_label(assigns.catalog.group_type, 1, capitalize: false)
      )

    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-7xl">
              <.page_header
                title="Preview"
                subtitle={"How this #{@group_word} appears to visitors in the arcade."}
                crumbs={[
                  {@creator.name, ~p"/creators/#{@creator.id}"},
                  {@catalog.name, ~p"/creators/catalogs/#{@catalog.id}"},
                  {@group.title, ~p"/creators/content_groups/#{@group.id}"}
                ]}
              >
                <:actions>
                  <a
                    href={content_group_iframe_url(@group)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="size-4" /> Open in new tab
                  </a>
                  <.link
                    navigate={~p"/creators/content_groups/#{@group.id}"}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-arrow-left" class="size-4" /> Back to {@group_word}
                  </.link>
                </:actions>
              </.page_header>

              <.panel
                id="group-preview"
                flush
                title={@group.title}
                description="The live arcade widget, exactly as embedded on your site."
              >
                <iframe
                  src={content_group_iframe_url(@group)}
                  class="block h-[70vh] min-h-[600px] w-full rounded-b-2xl bg-base-200/40"
                  title={"#{@group.title} preview"}
                >
                </iframe>
              </.panel>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
