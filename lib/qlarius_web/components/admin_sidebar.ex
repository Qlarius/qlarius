defmodule QlariusWeb.Components.AdminSidebar do
  use QlariusWeb, :html

  attr :current_user, :map, required: true

  def sidebar(assigns) do
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

    <div id="layout-sidebar" class="sidebar-menu sidebar-menu-activation">
      <div class="flex min-h-16 items-center justify-between gap-3 ps-5 pe-4">
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
        <div id="admin-sidebar-nav" data-simplebar class="size-full" phx-hook="AdminSidebar">
          <div class="mb-3 space-y-0.5 px-2.5">
            <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0">Consumer (You)</p>
            <div class="group collapse">
              <input
                id="sidebar-consumer"
                aria-label="Sidemenu item trigger"
                type="checkbox"
                class="peer"
                name="sidebar-menu-parent-item"
              />
              <div class="collapse-title px-2.5 py-1.5">
                <span class="iconify lucide--user size-4"></span>
                <span class="grow">{@current_user.alias}</span>
                <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
              </div>
              <div class="collapse-content ms-6.5 !p-0">
                <div class="mt-0.5 space-y-0.5">
                  <a class="menu-item false" href="/ads">
                    <span class="grow">Ads</span>
                  </a>
                  <a class="menu-item false" href="/wallet">
                    <span class="grow">Wallet</span>
                  </a>
                  <a class="menu-item false" href={~p"/referrals"}>
                    <span class="grow">Referrals</span>
                  </a>
                  <a class="menu-item false" href={~p"/me_file"}>
                    <span class="grow">MeFile</span>
                  </a>
                  <a class="menu-item false" href={~p"/me_file_builder"}>
                    <span class="grow">Tagger</span>
                  </a>
                  <a class="menu-item false" href={~p"/tiqits"}>
                    <span class="grow">Tiqits</span>
                  </a>
                </div>
              </div>
            </div>

            <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0">Business</p>
            <div class="group collapse">
              <input
                id="sidebar-marketer"
                aria-label="Sidemenu item trigger"
                type="checkbox"
                class="peer"
                name="sidebar-menu-parent-item"
              />
              <div class="collapse-title px-2.5 py-1.5">
                <span class="iconify lucide--megaphone size-4"></span>
                <span class="grow">Marketer</span>
                <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
              </div>
              <div class="collapse-content ms-6.5 !p-0">
                <div class="mt-0.5 space-y-0.5">
                  <a class="menu-item false" href={~p"/marketer/campaigns"}>
                    <span class="grow">Marketers</span>
                  </a>
                  <a class="menu-item false" href={~p"/marketer/campaigns"}>
                    <span class="grow">Campaigns</span>
                  </a>
                  <a class="menu-item false" href={~p"/marketer/targets"}>
                    <span class="grow">Targets</span>
                  </a>
                  <a class="menu-item false" href={~p"/marketer/traits"}>
                    <span class="grow">Tag Groups</span>
                  </a>
                  <a class="menu-item false" href={~p"/marketer/sequences"}>
                    <span class="grow">Sequences</span>
                  </a>
                  <a class="menu-item false" href={~p"/marketer/media"}>
                    <span class="grow">Media</span>
                  </a>
                </div>
              </div>
            </div>

            <div class="group collapse">
              <input
                id="sidebar-creator"
                aria-label="Sidemenu item trigger"
                type="checkbox"
                class="peer"
                name="sidebar-menu-parent-item"
              />
              <div class="collapse-title px-2.5 py-1.5">
                <span class="iconify lucide--video size-4"></span>
                <span class="grow">Creator</span>
                <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
              </div>
              <div class="collapse-content ms-6.5 !p-0">
                <div class="mt-0.5 space-y-0.5">
                  <a class="menu-item false" href={~p"/creators"}>
                    <span class="grow">Creators</span>
                  </a>
                  <a class="menu-item false" href="#">
                    <span class="grow">Dashboard</span>
                  </a>
                  <a class="menu-item false" href="#">
                    <span class="grow">Catalogs</span>
                  </a>
                  <a class="menu-item false" href="#">
                    <span class="grow">Groups</span>
                  </a>
                  <a class="menu-item false" href="#">
                    <span class="grow">Pieces</span>
                  </a>
                </div>
              </div>
            </div>

            <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0">Administration</p>
            <div class="group collapse">
              <input
                id="sidebar-admin"
                aria-label="Sidemenu item trigger"
                type="checkbox"
                class="peer"
                name="sidebar-menu-parent-item"
              />
              <div class="collapse-title px-2.5 py-1.5">
                <span class="iconify lucide--settings size-4"></span>
                <span class="grow">Admin</span>
                <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
              </div>
              <div class="collapse-content ms-6.5 !p-0">
                <div class="mt-0.5 space-y-0.5">
                  <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0 !text-sponster-500">
                    Sponster
                  </p>
                  <a class="menu-item false" href={~p"/admin/marketers"}>
                    <span class="grow">Marketers</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/recipients"}>
                    <span class="grow">Recipients</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/ad_categories"}>
                    <span class="grow">Ad Categories</span>
                  </a>

                  <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0 !text-youdata-500">
                    YouData
                  </p>
                  <a class="menu-item false" href={~p"/admin/traits"}>
                    <span class="grow">Trait Manager</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/surveys"}>
                    <span class="grow">Survey Manager</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/trait_categories"}>
                    <span class="grow">Trait Categories</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/survey_categories"}>
                    <span class="grow">Survey Categories</span>
                  </a>

                  <p class="menu-label px-2.5 pt-3 pb-1.5 first:pt-0">System</p>
                  <a class="menu-item false" href={~p"/admin/mefile_inspector"}>
                    <span class="grow">MeFile Inspector</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/alias_words"}>
                    <span class="grow">Alias Words</span>
                  </a>
                  <a class="menu-item false" href={~p"/admin/global_variables"}>
                    <span class="grow">Global Variables</span>
                  </a>
                  <a class="menu-item false" href="#">
                    <span class="grow">Sponster Ledger</span>
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="mb-2">
        <hr class="border-base-300 my-2 border-dashed" />
        <div class="dropdown dropdown-top dropdown-end w-full">
          <div
            tabindex="0"
            role="button"
            class="bg-base-200 hover:bg-base-300 rounded-box mx-2 mt-0 flex cursor-pointer items-center gap-2.5 px-3 py-2 transition-all"
          >
            <div class="avatar">
              <div class="bg-base-200 mask mask-squircle w-8">
                <img src="/images/qlarius_app_icon_180.png" alt="Avatar" />
              </div>
            </div>
            <div class="grow -space-y-0.5">
              <p class="text-sm font-medium">{@current_user.alias}</p>
            </div>
            <span class="iconify lucide--chevrons-up-down text-base-content/60 size-4"></span>
          </div>
          <ul
            role="menu"
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box shadow-base-content/4 mb-1 w-48 p-1 shadow-[0px_-10px_40px_0px]"
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
end
