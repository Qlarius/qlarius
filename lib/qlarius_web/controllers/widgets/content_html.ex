defmodule QlariusWeb.Widgets.ContentHTML do
  use QlariusWeb, :html

  import QlariusWeb.Components.TiqitUnlockedContent, only: [tiqit_unlocked_content_player: 1]

  def show(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100" data-theme={if @base_path == "/widgets", do: @force_theme}>
      <div class="container mx-auto px-4 py-4 max-w-4xl">
        <div class="mb-3">
          <.back navigate={
            if @force_theme && @base_path == "/widgets",
              do:
                "#{@base_path}/arqade/group/#{@content.content_group.id}?content_id=#{@content.id}&force_theme=#{@force_theme}",
              else:
                "#{@base_path}/arqade/group/#{@content.content_group.id}?content_id=#{@content.id}"
          }>
            To full {String.capitalize(to_string(@content.content_group.catalog.piece_type))} arqade
          </.back>
        </div>
        <div class="p-4">
          <%!--
          Dead-view render of the shared LiveView player. `YouTubePoster`
          is registered via app.js and attaches via LiveSocket, which
          initializes on every page that loads app.js — including this
          controller-rendered page. Replaces the previous inline
          `onclick="playVideo()"` + `<script>` duplicate.
          --%>
          <.tiqit_unlocked_content_player
            id_prefix={"content-#{@content.id}"}
            piece={@content}
            group={@content.content_group}
            tiqit={@tiqit}
          />
        </div>
      </div>
    </div>
    """
  end
end
