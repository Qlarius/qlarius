defmodule QlariusWeb.WhyYouPanel do
  @moduledoc """
  Full "Why you?" disclosure for recommended content.

  Mirrors the wallet drawer's matching-tags panel: same heading, the
  same `parent_traits_display` / `trait_card` rendering, and the same
  empty copy. Also names the creator and the attachment level.
  """
  use QlariusWeb, :html

  import QlariusWeb.MeFileHTML, only: [parent_traits_display: 1]

  attr :why_you, :map, default: nil

  def why_you_panel(assigns) do
    ~H"""
    <section :if={@why_you} id="why-you" class="mt-3 mb-2">
      <.surface_panel>
        <h4 class="text-sm font-semibold text-base-content/60 mb-2 px-0.5">
          Why you?
        </h4>
        <p :if={@why_you.source_copy} class="text-sm text-base-content mb-3 px-0.5">
          {@why_you.source_copy}
        </p>
        <%= if @why_you.parent_traits != [] do %>
          <.parent_traits_display
            parent_traits={@why_you.parent_traits}
            tag_display_mode="tag"
            readonly
          />
        <% else %>
          <p class="text-sm text-base-content/60 px-0.5">No matching info found</p>
        <% end %>
      </.surface_panel>
    </section>
    """
  end
end
