defmodule QlariusWeb.Components.QlinkTheme do
  @moduledoc """
  Shared Qlink public-page chrome: bio header, standard link cards, and the
  Style-tab phone preview. Markup is driven by `Qlarius.Qlink.Themes`.
  """
  use Phoenix.Component

  import QlariusWeb.CoreComponents, only: [icon: 1]

  alias Qlarius.Qlink.Themes

  attr :theme, :map, default: nil
  attr :page, :map, required: true
  attr :display_image, :string, required: true
  attr :preview, :boolean, default: false

  def bio_header(assigns) do
    assigns = assign(assigns, :header, Themes.header_mode(assigns.theme, assigns.page))

    ~H"""
    <div class={["qlink-header", @header == "hero" && "qlink-header--hero"]}>
      <%= if @header == "hero" do %>
        <div class="qlink-header__hero">
          <img src={@display_image} alt="" />
        </div>
      <% else %>
        <div class="qlink-header__avatar-wrap max-w-2xl mx-auto">
          <div class={[
            "qlink-header__avatar w-40 h-40 overflow-hidden shrink-0",
            avatar_shape_class(@theme)
          ]}>
            <img src={@display_image} alt={@page.title} />
          </div>
        </div>
      <% end %>

      <div class="qlink-header__copy max-w-2xl mx-auto">
        <h1 class="qlink-header__title">{@page.title}</h1>
        <%= if @page.bio_text not in [nil, ""] do %>
          <p class="qlink-header__bio">{@page.bio_text}</p>
        <% end %>

        <%= if @page.social_links && map_size(@page.social_links) > 0 do %>
          <div class="qlink-header__socials">
            <%= for {platform, url} <- @page.social_links do %>
              <% icon_path = social_icon_path(platform) %>
              <a
                href={if(@preview, do: nil, else: url)}
                target={if(@preview, do: nil, else: "_blank")}
                rel="noopener noreferrer"
                class="qlink-social-icon btn btn-circle btn-ghost outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
                title={String.capitalize(to_string(platform))}
              >
                <%= if icon_path do %>
                  <span
                    class="qlink-social-icon-img inline-block w-6 h-6 bg-current opacity-80"
                    style={"mask: url('#{icon_path}') center / contain no-repeat; -webkit-mask: url('#{icon_path}') center / contain no-repeat;"}
                    aria-hidden="true"
                  >
                  </span>
                <% else %>
                  <.icon name="hero-link" class="w-6 h-6" />
                <% end %>
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :link, :map, required: true
  attr :theme, :map, default: nil
  attr :page, :map, default: nil
  attr :preview, :boolean, default: false

  def standard_link(assigns) do
    thumb = Themes.first_party_src(assigns.link.thumbnail, assigns.page)
    layout = Themes.button_layout(assigns.theme, is_binary(thumb))
    themed? = Themes.themed?(assigns.theme)
    style = get_in(assigns.theme || %{}, ["button", "style"]) || "fill"
    href = if assigns.preview, do: nil, else: assigns.link.url

    assigns =
      assigns
      |> assign(:thumb, thumb)
      |> assign(:layout, layout)
      |> assign(:themed?, themed?)
      |> assign(:btn_style, style)
      |> assign(:href, href)

    ~H"""
    <.link_shell href={@href} class={link_card_classes(@themed?, @layout, @btn_style)}>
      <%= case @layout do %>
        <% "media" -> %>
          <img src={@thumb} alt="" class="qlink-link-card__media" />
          <div class="qlink-link-card__body">
            <.link_text link={@link} />
          </div>
          <%= if @link.icon not in [nil, ""] do %>
            <span class="qlink-link-card__badge">{@link.icon}</span>
          <% end %>
        <% "cover" -> %>
          <img src={@thumb} alt="" class="qlink-link-card__media" />
          <div class="qlink-link-card__body">
            <.link_text link={@link} />
          </div>
        <% "stack" -> %>
          <img src={@thumb} alt="" class="qlink-link-card__media" />
          <div class="qlink-link-card__body">
            <.link_text link={@link} />
          </div>
        <% _ -> %>
          <div class="qlink-link-card__classic">
            <%= if @themed? do %>
              <%= if @thumb do %>
                <img src={@thumb} alt="" class="qlink-link-card__thumb" />
              <% end %>
              <%= if @link.icon not in [nil, ""] and is_nil(@thumb) do %>
                <span class="text-2xl flex-shrink-0">{@link.icon}</span>
              <% end %>
              <div class="qlink-link-card__classic-copy">
                <.link_text link={@link} />
              </div>
              <%= if @link.icon not in [nil, ""] and @thumb do %>
                <span class="text-2xl flex-shrink-0">{@link.icon}</span>
              <% end %>
            <% else %>
              <%= if @link.icon not in [nil, ""] do %>
                <span class="text-2xl flex-shrink-0">{@link.icon}</span>
              <% end %>
              <div class="flex-1 text-left min-w-0">
                <.link_text link={@link} />
              </div>
              <%= if @thumb do %>
                <img src={@thumb} alt="" class="w-12 h-12 rounded object-cover flex-shrink-0" />
              <% end %>
            <% end %>
          </div>
      <% end %>
    </.link_shell>
    """
  end

  attr :page, :map, required: true
  attr :theme, :map, default: nil
  attr :display_image, :string, required: true
  attr :links, :list, default: []
  attr :embed_theme, :string, default: nil

  def phone_preview(assigns) do
    sample =
      case assigns.links do
        [] ->
          [
            %{title: "Your first link", description: nil, icon: nil, thumbnail: nil, url: "#"},
            %{
              title: "Add a photo for richer cards",
              description: nil,
              icon: nil,
              thumbnail: nil,
              url: "#"
            }
          ]

        links ->
          Enum.take(links, 4)
      end

    assigns =
      assigns
      |> assign(:sample_links, sample)
      |> assign(:css_vars, Themes.css_vars(assigns.theme))
      |> assign(:bg, Themes.background_css(assigns.page))
      |> assign(:page_classes, Themes.page_classes(assigns.theme))

    ~H"""
    <div class="qlink-phone-preview">
      <div class="qlink-phone-preview__frame">
        <div
          class={["qlink-public-page qlink-phone-preview__screen", @page_classes]}
          style={@css_vars}
        >
          <div class="qlink-public-page__column" style={@bg}>
            <.bio_header
              page={@page}
              theme={@theme}
              display_image={@display_image}
              preview={true}
            />
            <div class="qlink-phone-preview__links">
              <%= for link <- @sample_links do %>
                <.standard_link link={link} theme={@theme} page={@page} preview={true} />
              <% end %>
            </div>
            <%= if @embed_theme do %>
              <div class="qlink-phone-preview__widget" data-theme={@embed_theme}>
                <span class="qlink-phone-preview__widget-chip">
                  Widgets · {String.capitalize(@embed_theme)}
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :href, :string, default: nil
  attr :class, :any, required: true
  slot :inner_block, required: true

  defp link_shell(assigns) do
    ~H"""
    <%= if @href do %>
      <a
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
        class={@class}
      >
        {render_slot(@inner_block)}
      </a>
    <% else %>
      <div class={@class}>
        {render_slot(@inner_block)}
      </div>
    <% end %>
    """
  end

  attr :link, :map, required: true

  defp link_text(assigns) do
    ~H"""
    <div class="qlink-link-card__title">{@link.title}</div>
    <%= if @link.description not in [nil, ""] do %>
      <div class="qlink-link-card__desc">{@link.description}</div>
    <% end %>
    """
  end

  defp link_card_classes(themed?, layout, style) do
    base = [
      "qlink-link-card",
      "qlink-link-card--#{layout}",
      "block w-full outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
    ]

    if themed? do
      base ++ ["qlink-link-card--#{style}"]
    else
      base ++ ["rounded-full bg-base-200 border border-neutral/30 transition-colors"]
    end
  end

  defp avatar_shape_class(%{"avatar" => "rounded"}),
    do: "qlink-header__avatar--rounded rounded-2xl"

  defp avatar_shape_class(_), do: "qlink-header__avatar--circle rounded-full"

  defp social_icon_path(platform) do
    case to_string(platform) do
      "twitter" -> "/images/social-icons/x.svg"
      "instagram" -> "/images/social-icons/instagram.svg"
      "threads" -> "/images/social-icons/threads.svg"
      "facebook" -> "/images/social-icons/facebook.svg"
      "linkedin" -> "/images/social-icons/linkedin.svg"
      "youtube" -> "/images/social-icons/youtube.svg"
      "tiktok" -> "/images/social-icons/tiktok.svg"
      "github" -> "/images/social-icons/github.svg"
      _ -> nil
    end
  end
end
