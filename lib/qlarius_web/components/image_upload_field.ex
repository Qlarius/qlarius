defmodule QlariusWeb.Components.ImageUploadField do
  @moduledoc """
  Reusable image upload field component for LiveView forms.

  Provides a consistent UI for image uploads with drag-and-drop,
  preview, progress tracking, and current image display.
  """
  use Phoenix.Component

  import QlariusWeb.CoreComponents

  @doc """
  Renders an image upload field with preview and progress tracking.

  ## Examples

      <.image_upload_field
        upload={@uploads.image}
        label="Creator Image"
        current_image={@creator.image}
        current_image_url={CreatorImage.url({@creator.image, @creator}, :original)}
        on_delete="delete_image"
      />

  """
  attr :upload, Phoenix.LiveView.UploadConfig,
    required: true,
    doc: "The upload config from allow_upload"

  attr :label, :string, default: "Image", doc: "Label text for the upload field"
  attr :current_image, :string, default: nil, doc: "Current image filename (if editing)"
  attr :current_image_url, :string, default: nil, doc: "URL for current image preview"

  attr :on_delete, :string,
    default: nil,
    doc: "Event name for delete action (e.g., 'delete_image')"

  attr :accept_text, :string,
    default: "JPG, PNG, GIF, WebP (max 10MB)",
    doc: "Acceptable file types text"

  attr :preview_size, :string, default: "w-20 h-20", doc: "Preview image size classes"

  attr :current_image_size, :string,
    default: "w-16 h-16",
    doc: "Current image preview size classes"

  def image_upload_field(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if @label && String.trim(@label) != "" do %>
        <label class="label">
          <span class="label-text">{@label}</span>
        </label>
      <% end %>

      <div class={if @current_image && @current_image_url, do: "grid grid-cols-1 md:grid-cols-2 gap-4", else: ""}>
        <!-- Current Image (left column when exists) -->
        <%= if @current_image && @current_image_url do %>
          <div class="p-3 bg-base-200 rounded-lg relative">
            <%= if @on_delete do %>
              <button
                type="button"
                phx-click={@on_delete}
                data-confirm="Are you sure you want to delete this image?"
                class="btn btn-xs btn-ghost text-error absolute top-2 right-2"
                title="Delete Image"
              >
                <.icon name="hero-trash" class="w-5 h-5" />
              </button>
            <% end %>
            <img
              src={@current_image_url}
              class="w-full max-w-32 h-auto object-cover rounded-lg"
              alt="Current image preview"
            />
          </div>
        <% end %>

        <!-- Upload area (right column when current image exists, full width otherwise) -->
        <div
          class="w-full border-2 border-dashed border-base-300 rounded-lg flex items-center justify-center overflow-hidden"
          phx-drop-target={@upload.ref}
        >
          <.live_file_input upload={@upload} class="hidden" />
          <label
            for={@upload.ref}
            class="cursor-pointer p-6 text-center w-full block"
          >
            <.icon
              name="hero-cloud-arrow-up"
              class="w-8 h-8 mx-auto text-base-content/60 mb-2"
            />
            <p class="text-sm text-base-content/60">Click to upload or drag and drop</p>
            <p class="text-xs text-base-content/40">{@accept_text}</p>
          </label>
        </div>
      </div>

      <%= for entry <- @upload.entries do %>
        <div class="mt-2">
          <div class="flex items-center gap-3 p-3 bg-base-200 rounded-lg">
            <%= if entry.client_type =~ ~r/^image\// do %>
              <.live_img_preview entry={entry} class={"#{@preview_size} object-cover rounded-lg"} />
            <% else %>
              <.icon name="hero-document" class="w-8 h-8" />
            <% end %>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium truncate">{entry.client_name}</p>
              <div class="w-full bg-base-300 rounded-full h-2 mt-1">
                <div
                  class="bg-primary h-2 rounded-full transition-all duration-300"
                  style={"width: #{entry.progress}%"}
                >
                </div>
              </div>
              <p class="text-xs text-base-content/60 mt-1">{entry.progress}%</p>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              class="btn btn-xs btn-ghost flex-shrink-0"
              aria-label="Cancel upload"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
          <%= for err <- upload_errors(@upload, entry) do %>
            <div class="text-error text-xs mt-1">{error_to_string(err)}</div>
          <% end %>
        </div>
      <% end %>

      <%= for err <- upload_errors(@upload) do %>
        <div class="text-error text-xs mt-1">{error_to_string(err)}</div>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
