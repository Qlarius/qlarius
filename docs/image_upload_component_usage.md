# Image Upload Component Usage Guide

## Overview

The `ImageUploadField` component and `ImageUpload` helper module provide a DRY, reusable solution for handling image uploads across all LiveViews in the application.

## Components Created

1. **`QlariusWeb.Components.ImageUploadField`** - Function component for the template
2. **`QlariusWeb.LiveView.ImageUpload`** - Helper module for backend logic

## Usage

### Backend Setup

#### 1. Import the helper module

```elixir
alias QlariusWeb.LiveView.ImageUpload
```

#### 2. Setup upload configuration

Replace your existing `allow_upload` calls with:

```elixir
# Basic usage
socket = ImageUpload.setup_upload(socket, :image)

# With auto_upload enabled
socket = ImageUpload.setup_upload(socket, :image, auto_upload: true)

# Custom configuration
socket = ImageUpload.setup_upload(socket, :image,
  auto_upload: true,
  max_file_size: 5_000_000,
  accept: ~w(.jpg .jpeg .png)
)
```

#### 3. Consume uploaded files

Replace your `consume_uploaded_entries` calls with:

```elixir
# Simple usage - returns filename or nil
filename = ImageUpload.consume_upload(socket, :image, @creator, CreatorImage)

# Add to params map
params = ImageUpload.consume_and_add_to_params(
  socket,
  :image,
  @creator,
  CreatorImage,
  %{"name" => "Test"}
)
```

### Template Usage

Replace your entire upload UI section with:

```heex
<.image_upload_field
  upload={@uploads.image}
  label="Creator Image"
  current_image={@creator.image}
  current_image_url={CreatorImage.url({@creator.image, @creator}, :original)}
  on_delete="delete_image"
/>
```

#### Component Attributes

- `upload` (required) - The upload config from `allow_upload`
- `label` (optional) - Label text (default: "Image")
- `current_image` (optional) - Current image filename for display
- `current_image_url` (optional) - URL for current image preview
- `on_delete` (optional) - Event name for delete action (e.g., "delete_image")
- `accept_text` (optional) - File types text (default: "JPG, PNG, GIF, WebP (max 10MB)")
- `preview_size` (optional) - Preview image size classes (default: "w-20 h-20")
- `current_image_size` (optional) - Current image size classes (default: "w-16 h-16")

## Migration Examples

### Before (Creator Dashboard Show)

**Backend:**
```elixir
socket
|> allow_upload(:image,
  accept: ~w(.jpg .jpeg .png .gif .webp),
  max_entries: 1,
  max_file_size: 10_000_000,
  auto_upload: true
)

# In save handler
creator_params_with_image =
  case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
         upload = %Plug.Upload{
           path: path,
           filename: entry.client_name,
           content_type: entry.client_type
         }
         case CreatorImage.store({upload, socket.assigns.creator}) do
           {:ok, filename} -> {:ok, filename}
           error -> error
         end
       end) do
    [{:ok, filename} | _] -> Map.put(creator_params, "image", filename)
    [filename | _] when is_binary(filename) -> Map.put(creator_params, "image", filename)
    _ -> creator_params
  end
```

**Template:**
```heex
<div class="space-y-2">
  <label class="label">
    <span class="label-text">Creator Image</span>
  </label>
  <!-- 80+ lines of upload UI code -->
</div>
```

### After (Creator Dashboard Show)

**Backend:**
```elixir
alias QlariusWeb.LiveView.ImageUpload

socket
|> ImageUpload.setup_upload(:image, auto_upload: true)

# In save handler
creator_params_with_image =
  ImageUpload.consume_and_add_to_params(
    socket,
    :image,
    socket.assigns.creator,
    CreatorImage,
    creator_params
  )
```

**Template:**
```heex
<.image_upload_field
  upload={@uploads.image}
  label="Creator Image"
  current_image={@creator.image}
  current_image_url={CreatorImage.url({@creator.image, @creator}, :original)}
  on_delete="delete_image"
/>
```

## Files to Migrate

The following LiveViews can be migrated to use the new component:

1. ✅ `lib/qlarius_web/live/creator_dashboard/show.ex` - **DONE**
2. `lib/qlarius_web/live/creator_dashboard/index.ex`
3. `lib/qlarius_web/live/creators/qlink_page_live/form.ex`
4. `lib/qlarius_web/live/creators/catalog_live/form.ex`
5. `lib/qlarius_web/live/creators/content_group_live/form.ex`
6. `lib/qlarius_web/live/creators/content_piece_live/form.ex`
7. `lib/qlarius_web/live/marketers/media_piece_live.ex` (uses `:banner_image` instead of `:image`)

## Benefits

- **DRY**: Single source of truth for upload UI and logic
- **Consistent UX**: All uploads look and behave the same
- **Easy Maintenance**: Update once, applies everywhere
- **Less Code**: Reduces ~80 lines per form to ~5 lines
- **Type Safety**: Component validates attributes at compile time

