defmodule QlariusWeb.Creators.ContentGroupLive.Preview do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Creators

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    group = Creators.get_content_group!(id)

    {:ok,
     socket
     |> assign(:group, group)
     |> assign(:page_title, "Arcade Preview")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp content_group_iframe_url(group) do
    # For LiveView, we need to construct the URL differently
    origin = get_origin()
    scheme = get_scheme()
    "#{scheme}://#{origin}/widgets/arcade/group/#{group.id}"
  end

  defp get_origin do
    case System.get_env("PHX_HOST") do
      nil -> "localhost:4000"
      host -> host
    end
  end

  defp get_scheme do
    case System.get_env("PHX_HOST") do
      nil -> "http"
      _ -> "https"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <div class="container mx-auto px-4 py-8 max-w-6xl">
        <!-- Header -->
        <div class="card bg-base-100 shadow-xl mb-8">
          <div class="card-body">
            <div class="flex flex-row justify-between items-start sm:items-center gap-4">
              <div>
                <h1 class="text-3xl font-bold text-base-content">Arcade Preview</h1>
                <p class="text-base-content/60 mt-2">
                  Content Group: <span class="font-semibold text-primary">{@group.title}</span>
                </p>
              </div>
              <div class="flex gap-2">
                <.link navigate={~p"/creators/content_groups/#{@group.id}"} class="btn btn-outline">
                  <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Content Group
                </.link>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Preview Frame -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <div class="bg-base-200 h-full rounded-lg p-4 border border-base-300">
              <div class="flex items-center justify-center h-full">
                <iframe
                  src={content_group_iframe_url(@group)}
                  class="w-full h-[600px] border border-base-300"
                  title="Content Group Preview"
                >
                </iframe>
              </div>
            </div>

            <div class="mt-4 p-4 bg-base-200 rounded-lg">
              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <.icon name="hero-information-circle" class="w-4 h-4" />
                <span>
                  This is how your content group will appear to visitors. The iframe displays the actual arcade interface.
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
