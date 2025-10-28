# Current Marketer Selection

## Overview

The current marketer selection feature allows admin users to set a "working context" for managing campaigns and other marketer-specific operations. The selected marketer is stored in the Phoenix session and persists for the duration of the user's session.

## Implementation Details

### Storage
- **Location**: Phoenix session (server-side cookie)
- **Persistence**: Duration of user session
- **Scope**: Per user session across all tabs

### Components

1. **LiveView Module** (`lib/qlarius_web/live/admin/marketer_manager_live.ex`)
   - Displays marketers list with selection UI
   - Handles setting and displaying current marketer
   - Uses `Phoenix.LiveView.put_session/3` to persist selection

2. **Helper Module** (`lib/qlarius_web/live/current_marketer.ex`)
   - Utility functions for accessing current marketer in other LiveViews
   - Provides `on_mount` hook for easy integration

3. **UI Enhancements** (`lib/qlarius_web/components/core_components.ex`)
   - Added `row_class` attribute to table component for row highlighting

## Visual Indicators

### In Marketer Manager
- **Header Badge**: Green badge showing current marketer name
- **Table Row**: Highlighted with green tinted background and ring
- **Set Button**: First button in actions column, styled green with checkmark icon
  - Filled with ring when active (current marketer)
  - Outlined when inactive

## Usage in Other LiveViews

### Method 1: Manual Mount (Simple)

```elixir
defmodule QlariusWeb.Admin.CampaignManagerLive do
  use QlariusWeb, :live_view
  
  alias QlariusWeb.Live.CurrentMarketer
  alias Qlarius.Campaigns
  
  def mount(_params, session, socket) do
    # Read current marketer from session
    current_marketer_id = session["current_marketer_id"]
    socket = assign(socket, :current_marketer_id, current_marketer_id)
    {:ok, socket}
  end
  
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end
  
  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    
    # Get current marketer if set
    case CurrentMarketer.get_current_marketer(socket, scope) do
      {:ok, marketer} ->
        # Filter campaigns for this marketer
        campaigns = Campaigns.list_campaigns_for_marketer(scope, marketer.id)
        
        socket
        |> assign(:campaigns, campaigns)
        |> assign(:current_marketer, marketer)
      
      {:error, :not_set} ->
        # No marketer selected - show message or all campaigns
        socket
        |> assign(:campaigns, [])
        |> put_flash(:info, "Please select a marketer first")
      
      {:error, :not_found} ->
        # Selected marketer was deleted
        socket
        |> assign(:campaigns, [])
        |> Phoenix.LiveView.put_session(:current_marketer_id, nil)
        |> assign(:current_marketer_id, nil)
        |> put_flash(:warning, "Selected marketer no longer exists")
    end
  end
end
```

### Method 2: Using on_mount Hook (Cleaner)

```elixir
defmodule QlariusWeb.Admin.CampaignManagerLive do
  use QlariusWeb, :live_view
  
  alias QlariusWeb.Live.CurrentMarketer
  
  # Automatically load current_marketer_id from session
  on_mount {CurrentMarketer, :init_current_marketer}
  
  # Now mount/3 doesn't need to handle it
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
  
  # Rest of your LiveView...
end
```

### Template Example

```heex
<div class="p-6">
  <%= if @current_marketer do %>
    <div class="alert alert-info mb-4">
      <.icon name="hero-information-circle" class="w-5 h-5" />
      <span>Managing campaigns for: {@current_marketer.business_name}</span>
    </div>
  <% else %>
    <div class="alert alert-warning mb-4">
      <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
      <span>
        No marketer selected. 
        <.link navigate={~p"/admin/marketers"} class="link">Select one</.link>
      </span>
    </div>
  <% end %>
  
  <!-- Your campaigns list here -->
</div>
```

## Future Enhancements

Potential improvements to consider:
- Add a global navbar indicator of current marketer
- Add quick-switch dropdown in navbar
- Add context-aware breadcrumbs
- Add validation that selected marketer still exists on mount
- Add ability to clear selection (if needed)
- Add marketer-specific permissions checking

## Notes

- The feature is admin-only currently
- Non-admin users will be restricted to their linked marketer accounts
- The session value persists for the duration of the user's session
- Selection is shared across all browser tabs for the same user
- Session expires based on Phoenix session configuration (typically on logout or after timeout)

