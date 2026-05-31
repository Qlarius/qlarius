defmodule QlariusWeb.Widgets.ContentLive do
  @moduledoc """
  Displays unlocked content (e.g. video playback) for a valid tiqit.

  This is the in-app equivalent of ContentController. It wraps content
  in the mobile layout shell so users get full app chrome (nav, sidebar)
  when accessing content from /content/:id via tiqit cards.

  If the user lacks a valid tiqit, they're redirected to the arqade
  purchase page for the content's group.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Arcade
  alias QlariusWeb.Layouts

  import QlariusWeb.PWAHelpers
  import QlariusWeb.Components.TiqitUnlockedContent, only: [tiqit_unlocked_content_player: 1]
  import QlariusWeb.Widgets.Arcade.Components, only: [arqade_breadcrumbs: 1]

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(%{"id" => id}, session, socket) do
    piece =
      Arcade.get_content_piece!(id)
      |> Qlarius.Repo.preload(content_group: [catalog: :creator])

    scope = socket.assigns[:current_scope]

    case Arcade.get_valid_tiqit(scope, piece) do
      nil ->
        group_id = piece.content_group_id || piece.content_group.id

        {:ok,
         socket
         |> put_flash(:error, "You don't have access to this content")
         |> redirect(to: "/arqade/group/#{group_id}?content_id=#{piece.id}")}

      tiqit ->
        {:ok,
         socket
         |> init_pwa_assigns(session)
         |> assign(
           content: piece,
           tiqit: tiqit,
           title: "Arqade",
           current_path: "/content/#{id}"
         )}
    end
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="content-pwa-detect" phx-hook="PWADetect">
      <Layouts.maybe_mobile wrap={true} {assigns}>
        <div class="container mx-auto px-4 py-4 max-w-4xl">
          <.arqade_breadcrumbs
            base_path=""
            title={@content.title}
            title_class="text-2xl font-bold text-base-content truncate min-w-0"
            class="mb-4"
            crumbs={[
              {@content.content_group.catalog.creator.name, "/arqade"},
              {@content.content_group.catalog.name,
               "/arqade/catalog/#{@content.content_group.catalog.id}"},
              {@content.content_group.title, "/arqade/group/#{@content.content_group.id}"}
            ]}
            current={@content.title}
          />
          <div class="p-4">
            <.tiqit_unlocked_content_player
              id_prefix={"content-#{@content.id}"}
              piece={@content}
              group={@content.content_group}
              tiqit={@tiqit}
            />
          </div>
        </div>
      </Layouts.maybe_mobile>
    </div>
    """
  end
end
