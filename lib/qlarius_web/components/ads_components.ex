defmodule QlariusWeb.Components.AdsComponents do
  use Phoenix.Component

  attr :media_piece, :map, required: true
  attr :show_banner, :boolean, default: false

  def three_tap_ad(assigns) do
    ~H"""
    <div class="bg-base-200 dark:bg-base-900/20 rounded-lg overflow-hidden shadow-sm max-w-[340px]">
      <%= if @show_banner && @media_piece.banner_image do %>
        <div class="flex justify-center items-center bg-white">
          <img
            src={
              QlariusWeb.Uploaders.ThreeTapBanner.url(
                {@media_piece.banner_image, @media_piece},
                :original
              )
            }
            alt={@media_piece.title}
            class="w-full h-auto object-cover"
          />
        </div>
      <% end %>

      <div class="p-4">
        <div class="text-blue-600 dark:text-blue-300 mb-1 font-bold text-lg leading-tight">
          <a href={@media_piece.jump_url} target="_blank" class="hover:underline">
            {@media_piece.title}
          </a>
        </div>

        <%= if @media_piece.body_copy do %>
          <div class="text-base-content/70 text-sm mb-1" style="line-height: 1.1rem">
            {@media_piece.body_copy}
          </div>
        <% end %>

        <%= if @media_piece.display_url do %>
          <div class="text-green-500 text-xs mb-1">
            {@media_piece.display_url}
          </div>
        <% end %>

        <%= if @media_piece.jump_url do %>
          <div class="border-t border-base-300/30 mt-2 pt-2">
            <div class="text-xs text-base-content/50">
              <span class="font-semibold">LINK:</span>
              <a href={@media_piece.jump_url} target="_blank" class="link link-primary ml-1 truncate">
                {@media_piece.jump_url}
              </a>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
