# Mobile Layout Migration - Dual-Pane System

**Date**: January 11, 2026
**Status**: ✅ Complete

## Summary

Successfully migrated from inline slide-over panels to a new dual-pane layout system with proper modal support. The new system provides better separation of concerns, cleaner architecture, and proper full-viewport modal overlays.

## Changes Made

### 1. Layout Files (`lib/qlarius_web/layouts.ex`)

#### Created Backup
- Added `mobile_backup/1` function preserving the original `mobile/1` implementation
- Can be used for quick rollback if needed

#### New Mobile Layout
- Replaced `mobile/1` with the dual-pane implementation (formerly `mobile_test/1`)
- **Key Features**:
  - `.slide-panels` container for dual-pane sliding navigation
  - Independent scroll positions for main and slide-over panels
  - `:modals` slot for modals that overlay both panels
  - `:slide_over_content` slot for detail/editing screens
  - Dynamic z-index management using CSS `:has()` selector

#### New Modal Class
- Created `.modal-dual-pane` custom class for opt-in modal behavior
- Only affects modals explicitly marked with `dual_pane={true}`
- Features:
  - Full viewport coverage (`position: fixed`, `100vw × 100vh`)
  - Blurred backdrop over both panels
  - Drawer style on mobile (`align-items: flex-end`)
  - Centered on desktop
  - Covers dock with proper z-index stacking

### 2. LiveView Updates (`lib/qlarius_web/live/me_file_builder_live.ex`)

#### Restructured Layout Usage
```elixir
# OLD: Inline slide-over with custom CSS
<Layouts.mobile {assigns} title="Tagger">
  <.tag_edit_modal ... />
  <style>...</style>
  <div class="survey-panels">...</div>
</Layouts.mobile>

# NEW: Using layout's dual-pane system
<Layouts.mobile {assigns}
  title="Tagger"
  slide_over_active={@editing}
  slide_over_title={@survey_in_edit.name}
>
  <:modals>
    <.tag_edit_modal ... dual_pane={true} />
  </:modals>
  
  <:slide_over_content>
    <%!-- Survey editing UI --%>
  </:slide_over_content>
  
  <%!-- Main survey index --%>
</Layouts.mobile>
```

#### Event Handler Update
- Renamed `handle_event("close_edit", ...)` → `handle_event("close_slide_over", ...)`
- Matches the layout's "Back" button event

#### Removed Custom CSS
- Deleted inline `.survey-panels` styles
- Now handled by layout's `.slide-panels` CSS

### 3. Component Updates (`lib/qlarius_web/live/me_file_html.ex`)

#### Added `dual_pane` Attribute
```elixir
attr :dual_pane, :boolean, default: false

def tag_edit_modal(assigns) do
  ~H"""
  <div class={[
    "modal modal-bottom sm:modal-middle",
    @dual_pane && "modal-dual-pane",  # Opt-in for dual-pane behavior
    @show_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
  ]}>
  """
end
```

## Architecture Benefits

### Before
- ❌ Modals inside panel system (off-screen when panel hidden)
- ❌ Custom CSS for each LiveView
- ❌ Inconsistent slide-over behavior
- ❌ Difficult to maintain

### After
- ✅ Modals outside panel system (always visible)
- ✅ Centralized layout logic
- ✅ Consistent dual-pane UX across app
- ✅ Easy to extend with new LiveViews
- ✅ DaisyUI-safe (opt-in custom classes)

## Testing Performed

1. **Modal Opening**: ✅ Opens from both main and slide-over panels
2. **Modal Positioning**: ✅ Centered on desktop, drawer on mobile
3. **Modal Coverage**: ✅ Full viewport with blurred backdrop
4. **Dock Visibility**: ✅ Visible through backdrop, covered by modal
5. **Scroll Independence**: ✅ Main and slide-over panels maintain separate scroll positions
6. **Slide Animations**: ✅ Smooth 300ms transitions
7. **Back Button**: ✅ Closes slide-over, returns to main panel

## Rollback Instructions

If issues arise, quick rollback:

### Option 1: Use Backup Layout
```elixir
# In any affected LiveView
<Layouts.mobile_backup {assigns} title="...">
  <%!-- Old structure --%>
</Layouts.mobile_backup>
```

### Option 2: Git Revert
```bash
git diff HEAD -- lib/qlarius_web/layouts.ex
git diff HEAD -- lib/qlarius_web/live/me_file_builder_live.ex
git checkout HEAD -- <file_path>  # If needed
```

## Future Work

- [ ] Migrate `me_file_live.ex` to use dual-pane layout
- [ ] Migrate any other LiveViews using inline slide-overs
- [ ] Remove `mobile_test/1` and `mobile_backup/1` after confirming stability
- [ ] Consider extracting modal z-index logic to DaisyUI theme

## Files Modified

1. `lib/qlarius_web/layouts.ex`
   - Added `mobile_backup/1` (backup)
   - Replaced `mobile/1` with dual-pane implementation
   - Added `.modal-dual-pane` CSS class

2. `lib/qlarius_web/live/me_file_builder_live.ex`
   - Restructured to use `:modals` and `:slide_over_content` slots
   - Updated event handler name
   - Removed custom CSS

3. `lib/qlarius_web/live/me_file_html.ex`
   - Added `dual_pane` attribute to `tag_edit_modal/1`

4. `lib/qlarius_web/router.ex`
   - Removed test routes (`/mobile_test`, `/me_file_builder_test`)

5. `priv/static/service-worker.js`
   - Added localhost HTTPS → HTTP rewrite for PWA development

## Files Deleted

1. `lib/qlarius_web/live/mobile_test_live.ex` (test file, no longer needed)
2. `lib/qlarius_web/live/me_file_builder_test_live.ex` (test file, no longer needed)

## Files Created

1. `MOBILE_LAYOUT_MIGRATION.md` (this file)
   - Documentation of changes

## Notes

- Test files cleaned up after successful migration
- The `mobile_backup/1` layout preserved for emergency rollback
- Can be removed after confirming everything works in production
- All changes are backwards compatible (other LiveViews can adopt dual-pane gradually)
