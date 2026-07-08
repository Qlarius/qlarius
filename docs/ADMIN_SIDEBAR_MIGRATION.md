# Admin Sidebar & Topbar State Persistence - Implementation Guide

## ✅ What We've Implemented

We've moved the admin sidebar and topbar from the layout template into individual LiveViews using reusable components with `phx-update="ignore"`. This allows the sidebar state (expanded/collapsed sections + scroll position) to persist across navigation, and creates a proper layout where the sidebar is full-height on the left with the topbar on the right.

### Files Created/Modified:

1. **`lib/qlarius_web/components/admin_sidebar.ex`** - New sidebar component (full height)
2. **`lib/qlarius_web/components/admin_topbar.ex`** - New topbar component (right side only)
3. **`lib/qlarius_web/live/admin/mefile_inspector_live.ex`** - Example LiveView using the new pattern
4. **`lib/qlarius_web/live/admin/marketer_manager_live.ex`** - Example LiveView using the new pattern
5. **`assets/js/app.js`** - Simplified `AdminSidebar` hook
6. **`lib/qlarius_web/layouts/admin.html.heex`** - Simplified to just flash and content slot

## 🎯 How It Works

- **`phx-update="ignore"`** on the sidebar component preserves DOM state across LiveView patches
- **Inline `<script>`** in the component restores checkbox state on mount/refresh
- **Phoenix Hook** saves checkbox changes and manages scroll position with SimpleBar
- **localStorage** persists state across sessions

## 📝 How to Apply to Other Admin LiveViews

### Step 1: Add the aliases

```elixir
defmodule QlariusWeb.Admin.YourLive do
  use QlariusWeb, :live_view
  
  alias QlariusWeb.Components.AdminSidebar  # Add this
  alias QlariusWeb.Components.AdminTopbar   # Add this
  # ... other aliases
```

### Step 2: Update the render function

**Before:**
```elixir
def render(assigns) do
  ~H"""
  <Layouts.admin {assigns}>
    <div class="p-6">
      <!-- Your content -->
    </div>
  </Layouts.admin>
  """
end
```

**After:**
```elixir
def render(assigns) do
  ~H"""
  <Layouts.admin {assigns}>
    <div class="flex h-screen">
      <AdminSidebar.sidebar current_user={@current_scope.user} />

      <div class="flex min-w-0 grow flex-col">
        <AdminTopbar.topbar current_user={@current_scope.user} />

        <div class="overflow-auto">
          <div class="p-6">
            <!-- Your content -->
          </div>
        </div>
      </div>
    </div>
  </Layouts.admin>
  """
end
```

### Step 3: Close the extra divs at the end

Make sure to close the four additional `<div>` tags you added:

```elixir
          </div>  <!-- Close p-6 div -->
        </div>    <!-- Close overflow-auto div -->
      </div>      <!-- Close flex-col div -->
    </div>        <!-- Close flex h-screen div -->
  </Layouts.admin>
```

## 🔍 Find All Admin LiveViews

Run this command to find all admin LiveViews:

```bash
find lib/qlarius_web/live/admin -name "*_live.ex"
```

Or:

```bash
grep -r "use QlariusWeb, :live_view" lib/qlarius_web/live/admin/
```

## ✨ Testing

1. Navigate to `/admin/mefile_inspector` or `/admin/marketers`
2. Verify layout: sidebar on left (full height), topbar on right (top only)
3. Expand/collapse different sidebar sections
4. Scroll the sidebar
5. Navigate to another admin page (when you update it)
6. **Expected**: Sidebar state (expanded sections + scroll) persists ✓
7. **Expected**: Topbar appears correctly positioned with theme toggle and user menu ✓

## 🐛 Troubleshooting

### Sidebar refreshes on navigation
- Make sure `phx-update="ignore"` is on the outer sidebar container in `admin_sidebar.ex` ✓
- Verify the `AdminSidebar` alias is imported
- Check browser console for JS errors

### Scroll position not saving
- Verify SimpleBar is loaded (check for `.simplebar-content-wrapper` in DOM)
- Check browser localStorage for `admin_sidebar_scroll` key
- Increase timeout in hook if SimpleBar is slow to initialize

### State lost on refresh
- Check that the inline `<script>` tag in `admin_sidebar.ex` is present
- Verify localStorage keys exist: `admin_sidebar_consumer`, etc.
- Clear localStorage and test fresh

## 📊 Sidebar State Keys (localStorage)

- `admin_sidebar_consumer` - Consumer section state (true/false)
- `admin_sidebar_marketer` - Marketer section state  
- `admin_sidebar_creator` - Creator section state
- `admin_sidebar_admin` - Admin section state
- `admin_sidebar_scroll` - Scroll position (pixels)

## 🚀 Next Steps

1. Apply the pattern to all admin LiveViews (see Step 1-3 above)
2. Test each page to ensure sidebar persists
3. Consider removing old sidebar code from `admin.html.heex` layout (lines 10-280)
4. Delete this guide file when complete

## 💡 Why This Works

**Problem**: `phx-update="ignore"` doesn't work in layout templates because layouts are re-rendered on every navigation.

**Solution**: Move the sidebar into LiveView templates where `phx-update="ignore"` works as designed. The sidebar DOM is preserved across `patch` navigation, and localStorage provides persistence across full `navigate` events.

