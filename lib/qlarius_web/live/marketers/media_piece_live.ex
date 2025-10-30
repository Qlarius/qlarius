defmodule QlariusWeb.Live.Marketers.MediaPieceLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Live.Marketers.CurrentMarketer
  alias Qlarius.Sponster.Marketing
  alias Qlarius.Sponster.Ads.MediaPiece

  on_mount {CurrentMarketer, :load_current_marketer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    media_pieces =
      if socket.assigns.current_marketer_id do
        Marketing.list_media_pieces_for_marketer(socket.assigns.current_marketer_id)
      else
        []
      end

    socket
    |> assign(:page_title, "Media Pieces")
    |> assign(:media_piece, nil)
    |> assign(:media_pieces, media_pieces)
  end

  defp apply_action(socket, :new, _params) do
    changeset = Marketing.change_media_piece(%MediaPiece{})
    ad_categories = Marketing.list_ad_categories()

    socket
    |> assign(:page_title, "New Media Piece")
    |> assign(:media_piece, %MediaPiece{})
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
    |> assign(:ad_categories, ad_categories)
    |> allow_upload(:banner_image,
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 10_000_000
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    changeset = Marketing.change_media_piece(media_piece)
    ad_categories = Marketing.list_ad_categories()

    socket
    |> assign(:page_title, "Edit Media Piece")
    |> assign(:media_piece, media_piece)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
    |> assign(:ad_categories, ad_categories)
    |> allow_upload(:banner_image,
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 10_000_000
    )
  end

  @impl true
  def handle_event("validate", %{"media_piece" => attrs}, socket) do
    changeset =
      socket.assigns.media_piece
      |> Marketing.change_media_piece(attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"media_piece" => attrs}, socket) do
    save_media_piece(socket, socket.assigns.live_action, attrs)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media_piece = Marketing.get_media_piece!(id)
    {:ok, _} = Marketing.delete_media_piece(media_piece)

    {:noreply,
     socket
     |> put_flash(:info, "Media piece deleted successfully.")
     |> push_navigate(to: ~p"/marketer/media")}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :banner_image, ref)}
  end

  defp save_media_piece(socket, :new, attrs) do
    attrs_with_upload = maybe_add_banner_upload(socket, attrs)

    attrs_with_defaults =
      attrs_with_upload
      |> Map.put("marketer_id", socket.assigns.current_marketer_id)
      |> Map.put("media_piece_type_id", 1)
      |> Map.put("active", true)

    case Marketing.create_media_piece(attrs_with_defaults) do
      {:ok, _media_piece} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media piece created successfully.")
         |> push_navigate(to: ~p"/marketer/media")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_media_piece(socket, :edit, attrs) do
    attrs_with_upload = maybe_add_banner_upload(socket, attrs)

    case Marketing.update_media_piece(socket.assigns.media_piece, attrs_with_upload) do
      {:ok, _media_piece} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media piece updated successfully.")
         |> push_navigate(to: ~p"/marketer/media")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp maybe_add_banner_upload(socket, attrs) do
    uploaded_files =
      consume_uploaded_entries(socket, :banner_image, fn %{path: path}, entry ->
        {:ok, upload_and_get_filename(path, entry.client_name)}
      end)

    case uploaded_files do
      [filename | _] ->
        Map.put(attrs, "banner_image", filename)

      [] ->
        attrs
    end
  end

  defp upload_and_get_filename(source_path, original_filename) do
    ext = Path.extname(original_filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    case storage do
      Waffle.Storage.S3 ->
        upload_to_s3(source_path, filename)

      _ ->
        upload_to_local(source_path, filename)
    end

    filename
  end

  defp upload_to_local(source_path, filename) do
    dest_dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "banners",
        "three_tap_banners"
      ])

    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.cp!(source_path, dest_path)
  end

  defp upload_to_s3(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)

    s3_path = "uploads/media_pieces/banners/three_tap_banners/#{filename}"

    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <%= case @live_action do %>
        <% :index -> %>
          <.current_marketer_bar
            current_marketer={@current_marketer}
            current_path={~p"/marketer/media"}
          />
          <div class="container mx-auto px-4 py-8">
            <div class="flex justify-between items-center mb-8">
              <h1 class="text-3xl font-bold">Media Pieces</h1>
              <.link patch={~p"/marketer/media/new"}>
                <button class="btn btn-primary gap-2">
                  <.icon name="hero-plus" class="w-5 h-5" /> New Media Piece
                </button>
              </.link>
            </div>

            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-0">
                <div class="overflow-x-auto">
                  <table class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th class="bg-base-200">Banner</th>
                        <th class="bg-base-200">Title</th>
                        <th class="bg-base-200">Display URL</th>
                        <th class="bg-base-200">Ad Category</th>
                        <th class="bg-base-200">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for media_piece <- @media_pieces do %>
                        <tr class="hover">
                          <td class="align-top">
                            <%= if media_piece.banner_image do %>
                              <img
                                src={
                                  QlariusWeb.Uploaders.ThreeTapBanner.url(
                                    {media_piece.banner_image, media_piece},
                                    :original
                                  )
                                }
                                alt="Banner"
                                class="w-32 h-auto object-cover rounded"
                              />
                            <% else %>
                              <div class="w-32 h-24 bg-gray-200 rounded flex items-center justify-center">
                                <span class="text-gray-400">No banner</span>
                              </div>
                            <% end %>
                          </td>
                          <td class="align-top">{media_piece.title}</td>
                          <td class="text-emerald-600 align-top">{media_piece.display_url}</td>
                          <td class="align-top">
                            <span class="badge whitespace-nowrap inline-flex items-center">
                              {media_piece.ad_category.ad_category_name}
                            </span>
                          </td>
                          <td class="align-top">
                            <div class="flex gap-2">
                              <.link patch={~p"/marketer/media/#{media_piece}/edit"}>
                                <button class="btn btn-sm btn-ghost btn-square">
                                  <.icon name="hero-pencil-square" class="w-5 h-5" />
                                </button>
                              </.link>
                              <button
                                phx-click="delete"
                                phx-value-id={media_piece.id}
                                data-confirm="Are you sure you want to delete this media piece?"
                                class="btn btn-sm btn-ghost btn-square text-error"
                              >
                                <.icon name="hero-trash" class="w-5 h-5" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        <% :new -> %>
          <.current_marketer_bar
            current_marketer={@current_marketer}
            current_path={~p"/marketer/media"}
          />
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <.back navigate={~p"/marketer/media"}>Back to media pieces</.back>
            </div>
            <div>
              <.header>
                <h1 class="text-2xl font-bold">New Media Piece</h1>
                <:subtitle>Create a new media piece.</:subtitle>
              </.header>
            </div>
            <.media_piece_form
              form={@form}
              action={~p"/marketer/media/new"}
              ad_categories={@ad_categories}
              uploads={@uploads}
            />
          </div>
        <% :edit -> %>
          <.current_marketer_bar
            current_marketer={@current_marketer}
            current_path={~p"/marketer/media"}
          />
          <div class="container mx-auto px-4">
            <div class="mb-4">
              <.back navigate={~p"/marketer/media"}>Back to media pieces</.back>
            </div>
            <div>
              <.header>
                <h1 class="text-2xl font-bold">
                  Edit Media Piece "<span class="text-primary"><%= @media_piece.title %></span>"
                </h1>
                <:subtitle>Edit media piece information.</:subtitle>
              </.header>
            </div>
            <.media_piece_form
              form={@form}
              action={~p"/marketer/media/#{@media_piece}/edit"}
              ad_categories={@ad_categories}
              uploads={@uploads}
              media_piece={@media_piece}
            />
          </div>
      <% end %>
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :ad_categories, :list, required: true
  attr :uploads, :map, required: true
  attr :media_piece, :map, default: nil

  defp media_piece_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      id="media-piece-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-4"
    >
      <.input field={f[:title]} type="text" label="Title" required />
      <.input field={f[:body_copy]} type="textarea" label="Body Copy" />
      <.input field={f[:display_url]} type="text" label="Display URL" required />
      <.input field={f[:jump_url]} type="text" label="Jump URL" required />
      <.input
        field={f[:ad_category_id]}
        type="select"
        label="Ad Category"
        options={
          @ad_categories
          |> Enum.sort_by(& &1.ad_category_name)
          |> Enum.map(&{&1.ad_category_name, &1.id})
        }
        prompt="Select a category"
        required
      />

      <div>
        <label class="label">
          <span class="label-text">Banner Image</span>
        </label>

        <%= if @media_piece && @media_piece.banner_image do %>
          <div class="mb-4">
            <p class="text-sm text-base-content/70 mb-2">Current banner:</p>
            <img
              src={
                QlariusWeb.Uploaders.ThreeTapBanner.url(
                  {@media_piece.banner_image, @media_piece},
                  :original
                )
              }
              alt="Current banner"
              class="w-64 h-auto rounded"
            />
          </div>
        <% end %>

        <div
          class="border-2 border-dashed border-base-300 rounded-lg p-6"
          phx-drop-target={@uploads.banner_image.ref}
        >
          <div class="flex flex-col items-center gap-2">
            <.live_file_input
              upload={@uploads.banner_image}
              class="file-input file-input-bordered w-full max-w-md"
            />
            <p class="text-sm text-base-content/60">
              PNG, JPG, GIF up to 10MB
            </p>
          </div>
        </div>

        <%= for entry <- @uploads.banner_image.entries do %>
          <div class="mt-4 flex items-center gap-2">
            <.live_img_preview entry={entry} class="w-32 h-auto rounded" />
            <div class="flex-1">
              <p class="text-sm font-medium">{entry.client_name}</p>
              <progress value={entry.progress} max="100" class="progress progress-primary w-full">
                {entry.progress}%
              </progress>
            </div>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="btn btn-sm btn-ghost btn-circle"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <%= for err <- upload_errors(@uploads.banner_image) do %>
          <p class="text-error text-sm mt-2">
            {error_to_string(err)}
          </p>
        <% end %>
      </div>

      <div>
        <.button phx-disable-with="Saving..." class="btn btn-primary">Save Media Piece</.button>
        <.link navigate={~p"/marketer/media"} class="btn ml-2">Cancel</.link>
      </div>
    </.form>
    """
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files"
end
