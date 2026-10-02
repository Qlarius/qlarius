defmodule QlariusWeb.Components.CurrentMarketerBar do
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import QlariusWeb.CoreComponents, only: [icon: 1]

  attr :current_marketer, :any, default: nil
  attr :current_path, :string, required: true

  def current_marketer_bar(assigns) do
    ~H"""
    <div class="sticky top-0 z-30 border-b border-base-300 bg-base-200 px-6 py-3">
      <div class="flex items-center justify-between gap-6">
        <nav class="flex items-center gap-1">
          <.nav_item
            icon="hero-tag"
            label="Traits"
            path={~p"/marketer/traits"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="right" />

          <.nav_item
            icon="target-bullseye"
            label="Targets"
            path={~p"/marketer/targets"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="right" />

          <.nav_item
            icon="hero-megaphone"
            label="Campaigns"
            path={~p"/marketer/campaigns"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="left" />

          <.nav_item
            icon="hero-numbered-list"
            label="Sequences"
            path={~p"/marketer/sequences"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />

          <.arrow_icon direction="left" />

          <.nav_item
            icon="hero-photo"
            label="Media"
            path={~p"/marketer/media"}
            current_path={@current_path}
            disabled={is_nil(@current_marketer)}
          />
        </nav>

        <.marketer_switcher
          current_marketer={@current_marketer}
          on_switcher_page={@current_path == "/admin/marketers"}
        />
      </div>
    </div>
    """
  end

  attr :current_marketer, :any, required: true
  attr :on_switcher_page, :boolean, required: true

  defp marketer_switcher(%{current_marketer: nil} = assigns) do
    ~H"""
    <.link
      navigate={~p"/admin/marketers"}
      class="flex shrink-0 items-center gap-2 rounded-xl border border-dashed border-warning/60 bg-base-100 px-3 py-1.5 text-sm transition-colors hover:border-warning"
    >
      <.icon name="hero-exclamation-circle" class="size-5 text-warning" />
      <span class="font-medium">Select a marketer</span>
      <.icon name="hero-chevron-right" class="size-4 text-base-content/50" />
    </.link>
    """
  end

  defp marketer_switcher(assigns) do
    ~H"""
    <%= if @on_switcher_page do %>
      <div class={switcher_class()}>
        <.switcher_label current_marketer={@current_marketer} />
      </div>
    <% else %>
      <.link
        navigate={~p"/admin/marketers"}
        title="Switch marketer"
        class={["group transition-colors hover:border-base-content/30", switcher_class()]}
      >
        <.switcher_label current_marketer={@current_marketer} />
        <.icon
          name="hero-chevron-up-down"
          class="size-4 shrink-0 text-base-content/40 group-hover:text-base-content"
        />
      </.link>
    <% end %>
    """
  end

  defp switcher_class,
    do:
      "flex min-w-0 shrink-0 items-center gap-3 rounded-xl border border-base-300 bg-surface py-1.5 pr-3 pl-1.5 shadow-sm dark:bg-base-100"

  attr :current_marketer, :any, required: true

  defp switcher_label(assigns) do
    ~H"""
    <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-base-200 text-sm font-semibold text-base-content/70">
      {initials(@current_marketer.business_name)}
    </span>
    <span class="min-w-0 leading-tight">
      <span class="block text-[11px] text-base-content/50">Marketer</span>
      <span class="block max-w-48 truncate text-sm font-semibold">
        {@current_marketer.business_name}
      </span>
    </span>
    """
  end

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :current_path, :string, required: true
  attr :disabled, :boolean, default: false

  defp nav_item(assigns) do
    assigns = assign(assigns, :is_current, assigns.path == assigns.current_path)

    ~H"""
    <%= if @disabled do %>
      <div class="flex items-center gap-2 px-3 py-2 rounded-lg opacity-40 cursor-not-allowed">
        <%= if @icon == "target-bullseye" do %>
          <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor">
            <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="2.5" fill="currentColor" />
          </svg>
        <% else %>
          <.icon name={@icon} class="w-5 h-5" />
        <% end %>
        <span class="text-sm font-medium">{@label}</span>
      </div>
    <% else %>
      <.link
        navigate={@path}
        class={[
          "flex items-center gap-2 px-3 py-2 rounded-lg transition-colors",
          @is_current && "bg-primary text-primary-content",
          !@is_current && "hover:bg-base-300"
        ]}
      >
        <%= if @icon == "target-bullseye" do %>
          <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" stroke="currentColor">
            <circle cx="10" cy="10" r="8.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="5.5" stroke-width="1.5" />
            <circle cx="10" cy="10" r="2.5" fill="currentColor" />
          </svg>
        <% else %>
          <.icon name={@icon} class="w-5 h-5" />
        <% end %>
        <span class="text-sm font-medium">{@label}</span>
      </.link>
    <% end %>
    """
  end

  attr :direction, :string, required: true

  defp arrow_icon(assigns) do
    ~H"""
    <.icon
      name={if @direction == "right", do: "hero-arrow-right", else: "hero-arrow-left"}
      class="w-4 h-4 text-base-content/30"
    />
    """
  end
end
