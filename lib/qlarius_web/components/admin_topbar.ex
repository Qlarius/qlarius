defmodule QlariusWeb.Components.AdminTopbar do
  use QlariusWeb, :html

  alias QlariusWeb.Layouts

  attr :current_user, :map, required: true

  def topbar(assigns) do
    ~H"""
    <div
      role="navigation"
      aria-label="Navbar"
      class="flex items-center justify-between px-3 bg-base-100 border-b border-base-300 min-h-16"
      id="layout-topbar"
    >
      <div class="inline-flex items-center gap-3">
        <label
          class="btn btn-square btn-ghost btn-sm"
          aria-label="Leftmenu toggle"
          for="layout-sidebar-toggle-trigger"
        >
          <span class="iconify lucide--menu size-5"></span>
        </label>
      </div>

      <Layouts.theme_toggle />

      <div class="inline-flex items-center gap-1.5">
        <label
          for="layout-rightbar-drawer"
          class="btn btn-circle btn-ghost btn-sm drawer-button"
        >
          <span class="iconify lucide--settings-2 size-4.5"></span>
        </label>
        <div class="dropdown dropdown-bottom sm:dropdown-end max-sm:dropdown-center">
          <div
            tabindex="0"
            role="button"
            class="btn btn-circle btn-ghost btn-sm"
            aria-label="Notifications"
          >
            <span class="iconify lucide--bell size-4.5"></span>
          </div>
          <div
            tabindex="0"
            class="dropdown-content bg-base-100 rounded-box card card-compact mt-5 w-60 p-2 shadow sm:w-84"
          >
            <div class="flex items-center justify-between px-2">
              <p class="text-base font-medium">Notification</p>
              <button tabindex="0" class="btn btn-sm btn-circle btn-ghost" aria-label="Close">
                <span class="iconify lucide--x size-4"></span>
              </button>
            </div>
            <div class="flex items-center justify-center">
              <div class="badge badge-sm badge-primary badge-soft">
                Today
              </div>
            </div>
            <div class="mt-2">
              <div class="rounded-box hover:bg-base-200 flex cursor-pointer gap-3 px-2 py-1.5 transition-all">
                <div class="grow">
                  <p class="text-sm leading-tight">
                    Customer has requested a return for item
                  </p>
                  <p class="text-base-content/60 text-end text-xs leading-tight">
                    1 Hour ago
                  </p>
                </div>
              </div>
              <div class="rounded-box hover:bg-base-200 flex cursor-pointer gap-3 px-2 py-1.5 transition-all">
                <div class="grow">
                  <p class="text-sm leading-tight">
                    A new review has been submitted for product
                  </p>
                  <p class="text-base-content/60 text-end text-xs leading-tight">
                    1 Hour ago
                  </p>
                </div>
              </div>
            </div>
            <div class="mt-2 flex items-center justify-center">
              <div class="badge badge-sm">Previous</div>
            </div>
            <div class="mt-2">
              <div class="rounded-box hover:bg-base-200 flex cursor-pointer gap-3 px-2 py-1.5 transition-all">
                <div class="grow">
                  <p class="text-sm leading-tight">
                    Prepare for the upcoming weekend promotion
                  </p>
                  <p class="text-base-content/60 text-end text-xs leading-tight">
                    2 Days ago
                  </p>
                </div>
              </div>
              <div class="rounded-box hover:bg-base-200 flex cursor-pointer gap-3 px-2 py-1.5 transition-all">
                <div class="grow">
                  <p class="text-sm leading-tight">
                    Product 'ABC123' is running low in stock.
                  </p>
                  <p class="text-base-content/60 text-end text-xs leading-tight">
                    3 Days ago
                  </p>
                </div>
              </div>
              <div class="rounded-box hover:bg-base-200 flex cursor-pointer gap-3 px-2 py-1.5 transition-all">
                <div class="grow">
                  <p class="text-sm leading-tight">
                    Payment received for Order ID: #67890
                  </p>
                  <p class="text-base-content/60 text-end text-xs leading-tight">
                    Week ago
                  </p>
                </div>
              </div>
            </div>
            <hr class="border-base-300 -mx-2 mt-2" />
            <div class="flex items-center justify-between pt-2">
              <button class="btn btn-sm btn-ghost">Mark as read</button>
              <button class="btn btn-sm btn-soft btn-primary">
                View All
              </button>
            </div>
          </div>
        </div>
        <div class="dropdown dropdown-bottom dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost rounded-btn px-1.5">
            <div class="flex items-center gap-2">
              <div class="-space-y-0.5 text-start">
                <p class="text-sm">{@current_user.alias}</p>
              </div>
            </div>
          </div>
          <div tabindex="0" class="dropdown-content bg-base-100 rounded-box mt-4 w-44 shadow">
            <ul class="menu w-full p-2">
              <li>
                <div>
                  <span class="iconify lucide--user size-4"></span>
                  <span>My Profile</span>
                </div>
              </li>
              <li>
                <div>
                  <span class="iconify lucide--settings size-4"></span>
                  <span>Settings</span>
                </div>
              </li>
              <li>
                <div>
                  <span class="iconify lucide--arrow-left-right size-4"></span>
                  <span>Switch Account</span>
                </div>
              </li>
              <li>
                <div>
                  <span class="iconify lucide--help-circle size-4"></span>
                  <span>Help</span>
                </div>
              </li>
            </ul>
            <hr class="border-base-300" />
            <ul class="menu w-full p-2">
              <li>
                <a class="text-error hover:bg-error/10" href="./auth/login">
                  <span class="iconify lucide--log-out size-4"></span>
                  <span>Logout</span>
                </a>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
