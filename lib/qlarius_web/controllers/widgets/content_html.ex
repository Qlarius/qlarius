defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <div class="container mx-auto px-4 py-4 max-w-4xl">
        <div class="mb-3">
          <.back navigate={
            ~p"/widgets/arcade/group/#{@content.content_group}?content_id=#{@content.id}"
          }>
            Back to Arcade
          </.back>
        </div>
        <div class="p-4">
          <div class="aspect-video bg-base-200 rounded-box overflow-hidden mb-2 border border-base-300">
            <iframe
              class="w-full h-full"
              src={"https://www.youtube.com/embed/#{@content.youtube_id}"}
              title="YouTube video player"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              allowfullscreen
            >
            </iframe>
          </div>

          <div class="flex items-start justify-between mt-0">
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-base-content mb-0">
                {@content.title}
              </h1>
              <p class="text-base-content/70 text-sm mb-3">
                {@content.content_group.title}
              </p>
            </div>
          </div>

          <QlariusWeb.Components.TiqitExpirationCountdown.badge
            expires_at={@tiqit.expires_at}
            class="badge-outline badge-xs px-2 py-3 rounded-lg"
          />
        </div>
      </div>
    </div>
    """
  end
end
