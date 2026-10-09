defmodule QlariusWeb.Components.AdminSidebar do
  use QlariusWeb, :html

  attr :current_user, :map, required: true
  attr :current_path, :string, default: nil

  def sidebar(assigns) do
    sections = sections(assigns.current_user)

    assigns =
      assign(assigns,
        sections: sections,
        active: active_item(sections, assigns.current_path)
      )

    ~H"""
    <input
      type="checkbox"
      id="layout-sidebar-toggle-trigger"
      class="hidden"
      aria-label="Toggle layout sidebar"
    />
    <input
      type="checkbox"
      id="layout-sidebar-hover-trigger"
      class="hidden"
      aria-label="Dense layout sidebar"
    />
    <div id="layout-sidebar-hover" class="bg-base-300 h-screen w-1"></div>

    <div id="layout-sidebar" class="sidebar-menu">
      <div class="flex min-h-16 items-center justify-between gap-3 border-b border-base-300 ps-5 pe-4">
        <a href="/">
          <img alt="logo-light" class="h-8" src="/images/qadabra_full_gray_opt.svg" />
        </a>
        <label
          for="layout-sidebar-hover-trigger"
          title="Toggle sidebar hover"
          class="btn btn-circle btn-ghost btn-sm text-base-content/50 relative max-lg:hidden"
        >
          <span class="iconify lucide--panel-left-close absolute size-4.5 opacity-100 transition-all duration-300 group-has-[[id=layout-sidebar-hover-trigger]:checked]/html:opacity-0">
          </span>
          <span class="iconify lucide--panel-left-dashed absolute size-4.5 opacity-0 transition-all duration-300 group-has-[[id=layout-sidebar-hover-trigger]:checked]/html:opacity-100">
          </span>
        </label>
      </div>
      <div class="relative min-h-0 grow overflow-y-auto">
        <nav
          id="admin-sidebar-nav"
          class="size-full"
          phx-hook="AdminSidebar"
          phx-update="ignore"
        >
          <div class="space-y-1 px-3 pt-2 pb-4">
            <section :for={section <- @sections}>
              <p class="px-2 pt-4 pb-1.5 text-[11px] font-semibold uppercase tracking-wider text-base-content/40">
                {section.heading}
              </p>
              <div class="space-y-0.5">
                <.menu_group
                  :for={group <- section.groups}
                  group={group}
                  active={@active}
                />
              </div>
            </section>
          </div>
        </nav>
      </div>
      <div class="border-t border-base-300 p-3">
        <div class="dropdown dropdown-top dropdown-end w-full">
          <div
            tabindex="0"
            role="button"
            class="flex cursor-pointer items-center gap-2.5 rounded-xl border border-base-300 bg-base-100 px-3 py-2 shadow-xs transition-colors hover:bg-base-200"
          >
            <div class="avatar">
              <div class="mask mask-squircle w-8 bg-base-200">
                <img src="/images/qlarius_app_icon_180.png" alt="Avatar" />
              </div>
            </div>
            <div class="min-w-0 grow">
              <p class="truncate text-sm font-medium">{@current_user.alias}</p>
              <p class="text-xs text-base-content/50">Signed in</p>
            </div>
            <span class="iconify lucide--chevrons-up-down text-base-content/50 size-4"></span>
          </div>
          <ul
            role="menu"
            tabindex="0"
            class="dropdown-content menu mb-2 w-52 rounded-xl border border-base-300 bg-base-100 p-1 shadow-lg"
          >
            <li>
              <a href="/users/settings">
                <span class="iconify lucide--user size-4"></span>
                <span>My Profile</span>
              </a>
            </li>
            <li>
              <a href="/users/settings">
                <span class="iconify lucide--settings size-4"></span>
                <span>Settings</span>
              </a>
            </li>
            <li>
              <a href="#">
                <span class="iconify lucide--help-circle size-4"></span>
                <span>Help</span>
              </a>
            </li>
            <li>
              <div>
                <span class="iconify lucide--bell size-4"></span>
                <span>Notification</span>
              </div>
            </li>
            <li>
              <div>
                <span class="iconify lucide--arrow-left-right size-4"></span>
                <span>Switch Account</span>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <label for="layout-sidebar-toggle-trigger" id="layout-sidebar-backdrop"></label>
    """
  end

  attr :group, :map, required: true
  attr :active, :any, default: nil

  defp menu_group(assigns) do
    active_label =
      case assigns.active do
        {group_id, label} when group_id == assigns.group.id -> label
        _ -> nil
      end

    assigns =
      assign(assigns, active_label: active_label, contains_active?: active_label != nil)

    ~H"""
    <div class="group collapse" data-contains-active={@contains_active? && "true"}>
      <input
        id={@group.id}
        aria-label="Sidemenu item trigger"
        type="checkbox"
        class="peer"
        name="sidebar-menu-parent-item"
        checked={@contains_active?}
      />
      <div class={[
        "collapse-title !gap-2.5 px-2 py-1.5",
        @contains_active? && "text-base-content"
      ]}>
        <span class={[
          "flex size-7 shrink-0 items-center justify-center rounded-lg border transition-colors",
          if(@contains_active?,
            do: "border-primary/30 bg-primary/10 text-primary",
            else: "border-base-300 bg-base-100 text-base-content/60"
          )
        ]}>
          <span class={["iconify size-4", @group.icon]}></span>
        </span>
        <span class="min-w-0 grow truncate">{@group.label}</span>
        <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
      </div>
      <div class="collapse-content ms-6 !p-0">
        <div class="mt-1 mb-2 space-y-0.5 border-s border-base-300 ps-2">
          <%= for item <- @group.items do %>
            <p
              :if={item[:subheading]}
              class="flex items-center gap-2 px-2.5 pt-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-base-content/50"
            >
              <span class={["size-1.5 rounded-full", item.dot]}></span>
              {item.subheading}
            </p>
            <a
              :if={item[:href]}
              href={item.href}
              aria-current={item.label == @active_label && "page"}
              class={[
                "relative flex h-8 items-center rounded-lg px-2.5 text-sm transition-colors",
                if(item.label == @active_label,
                  do: "bg-primary/10 font-medium text-primary",
                  else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                ),
                item.href == "#" && "opacity-60"
              ]}
            >
              <span
                :if={item.label == @active_label}
                class="absolute -start-2.5 top-1.5 bottom-1.5 w-0.5 rounded-full bg-primary"
              >
              </span>
              <span class="truncate">{item.label}</span>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp sections(user) do
    [
      %{
        heading: "Consumer (You)",
        groups: [
          %{
            id: "sidebar-consumer",
            icon: "lucide--user",
            label: user.alias,
            items: [
              nav_link("Ads", ~p"/ads"),
              nav_link("Wallet", ~p"/wallet"),
              nav_link("Referrals", ~p"/referrals"),
              nav_link("MeFile", ~p"/me_file"),
              nav_link("Tagger", ~p"/me_file_builder"),
              nav_link("Tiqits", ~p"/tiqits")
            ]
          }
        ]
      },
      %{
        heading: "Business",
        groups: [
          %{
            id: "sidebar-marketer",
            icon: "lucide--megaphone",
            label: "Marketer",
            items: [
              nav_link("Campaigns", ~p"/marketer/campaigns"),
              nav_link("Targets", ~p"/marketer/targets"),
              nav_link("Tag Groups", ~p"/marketer/traits"),
              nav_link("Sequences", ~p"/marketer/sequences"),
              nav_link("Media", ~p"/marketer/media")
            ]
          },
          %{
            id: "sidebar-creator",
            icon: "lucide--video",
            label: "Creator",
            items: [
              nav_link("Creators", ~p"/creators"),
              nav_link("Link-in-bio Migration", ~p"/creators/link_in_bio_migration"),
              nav_link("Dashboard", "#"),
              nav_link("Catalogs", "#"),
              nav_link("Groups", "#"),
              nav_link("Pieces", "#")
            ]
          }
        ]
      },
      %{
        heading: "Administration",
        groups: [
          %{
            id: "sidebar-admin",
            icon: "lucide--settings",
            label: "Admin",
            items: [
              subheading("Sponster", "bg-sponster-500"),
              nav_link("Marketers", ~p"/admin/marketers"),
              nav_link("Recipients", ~p"/admin/recipients"),
              nav_link("Ad Categories", ~p"/admin/ad_categories"),
              subheading("YouData", "bg-youdata-500"),
              nav_link("Trait Manager", ~p"/admin/traits"),
              nav_link("Traits Index (JSON)", ~p"/admin/traits_index"),
              nav_link("MeFile Tags Map (JSON)", ~p"/admin/mefile_tags_index"),
              nav_link("Survey Manager", ~p"/admin/surveys"),
              nav_link("Trait Categories", ~p"/admin/trait_categories"),
              nav_link("Survey Categories", ~p"/admin/survey_categories"),
              subheading("System", "bg-base-content/30"),
              nav_link("MeFile Inspector", ~p"/admin/mefile_inspector"),
              nav_link("Alias Words", ~p"/admin/alias_words"),
              nav_link("Global Variables", ~p"/admin/global_variables"),
              nav_link("Sponster Ledger", ~p"/admin/sponster_ledger"),
              nav_link("MeCP Access Log", ~p"/admin/mecp_access_log"),
              nav_link("Qai Oracle", ~p"/admin/qai_oracle"),
              nav_link("Qai Economics", ~p"/admin/qai_economics")
            ]
          }
        ]
      }
    ]
  end

  defp nav_link(label, href), do: %{label: label, href: href}
  defp subheading(text, dot), do: %{subheading: text, dot: dot}

  # Longest matching href wins so /creators/link_in_bio_migration beats /creators.
  defp active_item(_sections, nil), do: nil

  defp active_item(sections, current_path) do
    sections
    |> Enum.flat_map(& &1.groups)
    |> Enum.flat_map(fn group -> Enum.map(group.items, &{group.id, &1}) end)
    |> Enum.filter(fn {_group_id, item} -> matches?(item, current_path) end)
    |> Enum.max_by(fn {_group_id, item} -> String.length(item.href) end, fn -> nil end)
    |> case do
      {group_id, item} -> {group_id, item.label}
      nil -> nil
    end
  end

  defp matches?(%{href: "#"}, _path), do: false

  defp matches?(%{href: href}, path),
    do: path == href or String.starts_with?(path, href <> "/")

  defp matches?(_subheading, _path), do: false
end
