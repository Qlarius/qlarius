defmodule QlariusWeb.Live.Marketers.MediaPieceLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias QlariusWeb.Live.Marketers.CurrentMarketer
  alias Qlarius.Sponster.Marketing
  alias Qlarius.Sponster.Ads.{AdCategories, MediaPiece}
  alias QlariusWeb.Components.SearchSelect
  import QlariusWeb.Components.AdsComponents, only: [video_thumbnail: 1]
  import QlariusWeb.Components.MarketerUI

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
    ad_category_options = AdCategories.picker_options()

    socket
    |> assign(:page_title, "New Media Piece")
    |> assign(:media_piece, %MediaPiece{})
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
    |> assign(:ad_category_options, ad_category_options)
    |> assign(:selected_media_type, "three_tap")
    |> allow_upload(:banner_image,
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true
    )
    |> allow_upload(:video_file,
      accept: ~w(.mp4),
      max_entries: 1,
      max_file_size: 100_000_000,
      auto_upload: true
    )
    |> allow_upload(:video_poster_image,
      accept: ~w(.jpg .jpeg .png .gif .webp),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    media_piece = Marketing.get_media_piece!(id)
    changeset = Marketing.change_media_piece(media_piece)
    ad_category_options = AdCategories.picker_options(media_piece.ad_category_id)

    selected_media_type =
      case media_piece.media_piece_type_id do
        2 -> "video"
        _ -> "three_tap"
      end

    socket
    |> assign(:page_title, "Edit Media Piece")
    |> assign(:media_piece, media_piece)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset))
    |> assign(:ad_category_options, ad_category_options)
    |> assign(:selected_media_type, selected_media_type)
    |> allow_upload(:banner_image,
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true
    )
    |> allow_upload(:video_file,
      accept: ~w(.mp4),
      max_entries: 1,
      max_file_size: 100_000_000,
      auto_upload: true
    )
    |> allow_upload(:video_poster_image,
      accept: ~w(.jpg .jpeg .png .gif .webp),
      max_entries: 1,
      max_file_size: 10_000_000,
      auto_upload: true
    )
  end

  @impl true
  def handle_event("select_media_type", %{"type" => media_type}, socket) do
    {:noreply, assign(socket, :selected_media_type, media_type)}
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
  def handle_event("save", %{"media_piece" => attrs} = params, socket) do
    socket =
      assign(socket, :return_to, safe_return_to(params["return_to"], ~p"/marketer/media"))

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
  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    upload_atom = String.to_existing_atom(upload_name)
    {:noreply, cancel_upload(socket, upload_atom, ref)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :banner_image, ref)}
  end

  @impl true
  def handle_info({SearchSelect, "ad-category-picker", value}, socket) do
    params = Map.put(socket.assigns.form.params || %{}, "ad_category_id", value)

    changeset =
      socket.assigns.media_piece
      |> Marketing.change_media_piece(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset))}
  end

  defp save_media_piece(socket, :new, attrs) do
    media_piece_type_id =
      case socket.assigns.selected_media_type do
        "video" -> 2
        _ -> 1
      end

    attrs_with_upload =
      attrs
      |> maybe_add_banner_upload(socket)
      |> maybe_add_video_upload(socket)
      |> maybe_add_video_poster_upload(socket)

    attrs_with_defaults =
      attrs_with_upload
      |> Map.put("marketer_id", socket.assigns.current_marketer_id)
      |> Map.put("media_piece_type_id", media_piece_type_id)
      |> Map.put("active", true)

    case Marketing.create_media_piece(attrs_with_defaults) do
      {:ok, _media_piece} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media piece created successfully.")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_media_piece(socket, :edit, attrs) do
    attrs_with_upload =
      attrs
      |> maybe_add_banner_upload(socket)
      |> maybe_add_video_upload(socket)
      |> maybe_add_video_poster_upload(socket)

    case Marketing.update_media_piece(socket.assigns.media_piece, attrs_with_upload) do
      {:ok, _media_piece} ->
        {:noreply,
         socket
         |> put_flash(:info, "Media piece updated successfully.")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  defp maybe_add_banner_upload(attrs, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :banner_image, fn %{path: path}, entry ->
        {:ok, upload_banner_and_get_filename(path, entry.client_name)}
      end)

    case uploaded_files do
      [filename | _] ->
        Map.put(attrs, "banner_image", filename)

      [] ->
        attrs
    end
  end

  defp maybe_add_video_upload(attrs, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :video_file, fn %{path: path}, entry ->
        {:ok, upload_video_and_get_filename(path, entry.client_name)}
      end)

    case uploaded_files do
      [filename | _] ->
        Map.put(attrs, "video_file", filename)

      [] ->
        attrs
    end
  end

  defp maybe_add_video_poster_upload(attrs, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :video_poster_image, fn %{path: path}, entry ->
        {:ok, upload_video_poster_and_get_filename(path, entry.client_name)}
      end)

    case uploaded_files do
      [filename | _] ->
        Map.put(attrs, "video_poster_image", filename)

      [] ->
        attrs
    end
  end

  defp upload_banner_and_get_filename(source_path, original_filename) do
    ext = Path.extname(original_filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    case storage do
      Waffle.Storage.S3 ->
        upload_banner_to_s3(source_path, filename)

      _ ->
        upload_banner_to_local(source_path, filename)
    end

    filename
  end

  defp upload_video_and_get_filename(source_path, original_filename) do
    ext = Path.extname(original_filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    case storage do
      Waffle.Storage.S3 ->
        upload_video_to_s3(source_path, filename)

      _ ->
        upload_video_to_local(source_path, filename)
    end

    filename
  end

  defp upload_banner_to_local(source_path, filename) do
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

  defp upload_banner_to_s3(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)
    s3_path = "uploads/media_pieces/banners/three_tap_banners/#{filename}"
    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
  end

  defp upload_video_to_local(source_path, filename) do
    dest_dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "videos"
      ])

    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.cp!(source_path, dest_path)
  end

  defp upload_video_to_s3(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)
    s3_path = "uploads/media_pieces/videos/#{filename}"
    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
  end

  defp upload_video_poster_and_get_filename(source_path, original_filename) do
    ext = Path.extname(original_filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    case storage do
      Waffle.Storage.S3 ->
        upload_video_poster_to_s3(source_path, filename)

      _ ->
        upload_video_poster_to_local(source_path, filename)
    end

    filename
  end

  defp upload_video_poster_to_local(source_path, filename) do
    dest_dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "videos",
        "posters"
      ])

    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.cp!(source_path, dest_path)
  end

  defp upload_video_poster_to_s3(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)
    s3_path = "uploads/media_pieces/videos/posters/#{filename}"
    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/marketer/media"}
            />
            <%= cond do %>
              <% !@current_marketer and @live_action in [:index, :new] -> %>
                <.no_marketer_notice message="Choose a marketer to manage their media pieces." />
              <% @live_action == :index -> %>
                <.media_index media_pieces={@media_pieces} />
              <% true -> %>
                <.page class="max-w-6xl">
                  <.page_header
                    back_to={~p"/marketer/media"}
                    back_label="Media pieces"
                    title={if @live_action == :new, do: "New media piece", else: "Edit media piece"}
                    subtitle={
                      if @live_action == :new,
                        do: "Create a 3-tap banner or video ad.",
                        else: @media_piece.title
                    }
                  />

                  <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_349px]">
                    <.media_piece_form
                      form={@form}
                      ad_category_options={@ad_category_options}
                      uploads={@uploads}
                      media_piece={if @live_action == :edit, do: @media_piece}
                      selected_media_type={@selected_media_type}
                    />
                    <.ad_preview
                      changeset={@changeset}
                      media_piece={@media_piece}
                      uploads={@uploads}
                      selected_media_type={@selected_media_type}
                    />
                  </div>
                </.page>
                <.unsaved_changes_dialog message="This media piece has unsaved changes. Save them before you leave?" />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :media_pieces, :list, required: true

  defp media_index(assigns) do
    ~H"""
    <.page>
      <.page_header
        title="Media pieces"
        count={length(@media_pieces)}
        subtitle="The banner and video ads you place into sequences."
      >
        <:actions>
          <.link patch={~p"/marketer/media/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-5" /> New media piece
          </.link>
        </:actions>
      </.page_header>

      <.panel flush>
        <.empty_state :if={@media_pieces == []} icon="hero-photo" title="No media pieces yet">
          Create a 3-tap banner or video ad to use in your sequences.
          <:action>
            <.link patch={~p"/marketer/media/new"} class="btn btn-primary btn-sm">
              New media piece
            </.link>
          </:action>
        </.empty_state>

        <ul :if={@media_pieces != []} class="divide-y divide-base-300">
          <li
            :for={media_piece <- @media_pieces}
            id={"media-piece-#{media_piece.id}"}
            class="group flex items-center gap-5 px-6 py-4 transition-colors hover:bg-base-200/40"
          >
            <div class="w-40 shrink-0">
              <%= cond do %>
                <% media_piece.media_piece_type_id == 2 -> %>
                  <.video_thumbnail
                    media_piece={media_piece}
                    class="w-full"
                    id={"mp-admin-#{media_piece.id}"}
                  />
                <% media_piece.banner_image -> %>
                  <img
                    src={
                      QlariusWeb.Uploaders.ThreeTapBanner.url(
                        {media_piece.banner_image, media_piece},
                        :original
                      )
                    }
                    alt=""
                    class="aspect-[3/1] w-full rounded-md border border-base-300 bg-white object-cover"
                  />
                <% true -> %>
                  <div class="flex aspect-[3/1] w-full items-center justify-center rounded-md bg-base-200 text-xs text-base-content/50">
                    No banner
                  </div>
              <% end %>
            </div>

            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <.icon
                  name={
                    if media_piece.media_piece_type_id == 2,
                      do: "hero-play-circle",
                      else: "hero-photo"
                  }
                  class="size-4 shrink-0 text-base-content/40"
                />
                <.link
                  patch={~p"/marketer/media/#{media_piece}/edit"}
                  class="truncate font-semibold hover:underline"
                >
                  {media_piece.title}
                </.link>
              </div>
              <p :if={media_piece.display_url} class="mt-0.5 truncate text-sm text-success">
                {media_piece.display_url}
              </p>
              <div :if={media_piece.ad_category} class="mt-2">
                <.chip>{media_piece.ad_category.ad_label}</.chip>
              </div>
            </div>

            <div class="flex shrink-0 items-center gap-1">
              <.link
                patch={~p"/marketer/media/#{media_piece}/edit"}
                class="btn btn-sm btn-ghost"
                aria-label={"Edit #{media_piece.title}"}
              >
                <.icon name="hero-pencil-square" class="size-4" /> Edit
              </.link>
              <button
                type="button"
                phx-click="delete"
                phx-value-id={media_piece.id}
                data-confirm="Delete this media piece? This cannot be undone."
                class="btn btn-sm btn-ghost btn-square text-error"
                aria-label={"Delete #{media_piece.title}"}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </li>
        </ul>
      </.panel>
    </.page>
    """
  end

  attr :form, :any, required: true
  attr :ad_category_options, :list, required: true
  attr :uploads, :map, required: true
  attr :media_piece, :map, default: nil
  attr :selected_media_type, :string, required: true

  defp media_piece_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      id="media-piece-form"
      phx-change="validate"
      phx-submit="save"
      phx-hook="UnsavedChanges"
      data-dirty={to_string(unsaved_changes?(@form, @uploads))}
      data-dialog="unsaved-changes-dialog"
      class="space-y-6"
    >
      <.panel title="Ad type">
        <div class="grid gap-3 sm:grid-cols-2">
          <.media_type_option
            value="three_tap"
            selected={@selected_media_type}
            icon="hero-photo"
            label="3-Tap Banner"
            description="Banner image with a title, copy and link"
          />
          <.media_type_option
            value="video"
            selected={@selected_media_type}
            icon="hero-play-circle"
            label="Video Ad"
            description="Short video with an optional poster image"
          />
        </div>
      </.panel>

      <.panel title="Content" description="What people see in the ad.">
        <%= if @selected_media_type == "three_tap" do %>
          <.input
            field={f[:title]}
            type="text"
            label={"Title (#{MediaPiece.three_tap_title_max()} characters)"}
            required
            maxlength={MediaPiece.three_tap_title_max()}
          />
          <.input
            field={f[:body_copy]}
            type="textarea"
            label={"Body Copy (#{MediaPiece.three_tap_body_max()} characters)"}
            rows="3"
            maxlength={MediaPiece.three_tap_body_max()}
          />
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:display_url]} type="text" label="Display URL" required />
            <.input field={f[:jump_url]} type="text" label="Jump URL" required />
          </div>
        <% else %>
          <.input field={f[:title]} type="text" label="Title" required />
        <% end %>
      </.panel>

      <.panel title="Ad category" description="Helps match the ad to the right audience.">
        <.live_component
          module={SearchSelect}
          id="ad-category-picker"
          field={f[:ad_category_id]}
          options={@ad_category_options}
          label="Ad Category"
          placeholder="Type words like pizza, yoga or car repair"
          required
        >
          <:footer>{AdCategories.iab_attribution()}</:footer>
        </.live_component>
      </.panel>

      <.panel
        title="Media"
        description={
          if @selected_media_type == "three_tap",
            do: "The banner shown above the ad copy.",
            else: "The video file and the image shown before it plays."
        }
      >
        <%= if @selected_media_type == "three_tap" do %>
          <.image_upload_field
            upload={@uploads.banner_image}
            label="Banner Image"
            current_image={if @media_piece, do: @media_piece.banner_image}
            current_image_url={
              if @media_piece && @media_piece.banner_image,
                do:
                  QlariusWeb.Uploaders.ThreeTapBanner.url(
                    {@media_piece.banner_image, @media_piece},
                    :original
                  )
            }
            accept_text="PNG, JPG, GIF (max 10MB)"
            preview_size="w-32 h-auto"
            current_image_size="w-64 h-auto"
            current_image_class="w-full h-auto rounded-lg object-cover"
          />
        <% else %>
          <.input
            field={f[:duration]}
            type="number"
            label="Video Duration (seconds)"
            required
            min="1"
            step="1"
          />

          <div class="space-y-2">
            <label class="label">
              <span class="label-text">Video File</span>
            </label>

            <p
              :if={@media_piece && @media_piece.video_file}
              class="flex items-center gap-2 text-sm text-base-content/70"
            >
              <.icon name="hero-check-circle" class="size-4 text-success" />
              A video is uploaded and shown in the preview. Upload a new file to replace it.
            </p>

            <div
              class="flex w-full items-center justify-center overflow-hidden rounded-lg border-2 border-dashed border-base-300"
              phx-drop-target={@uploads.video_file.ref}
            >
              <.live_file_input upload={@uploads.video_file} class="hidden" />
              <label for={@uploads.video_file.ref} class="block w-full cursor-pointer p-6 text-center">
                <.icon name="hero-cloud-arrow-up" class="mx-auto mb-2 size-8 text-base-content/60" />
                <p class="text-sm text-base-content/60">Click to upload or drag and drop</p>
                <p class="text-xs text-base-content/40">MP4 (max 100MB)</p>
              </label>
            </div>

            <%= for entry <- @uploads.video_file.entries do %>
              <div class="flex items-center gap-3 rounded-lg bg-base-200 p-3">
                <.icon name="hero-film" class="size-5 shrink-0 text-base-content/60" />
                <span class="min-w-0 flex-1 truncate text-sm">{entry.client_name}</span>
                <progress class="progress progress-primary w-32" value={entry.progress} max="100">
                </progress>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  phx-value-upload="video_file"
                  class="btn btn-sm btn-ghost btn-square"
                  aria-label="Cancel upload"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>
            <% end %>

            <%= for err <- upload_errors(@uploads.video_file) do %>
              <p class="text-sm text-error">{error_to_string(err)}</p>
            <% end %>
          </div>

          <.image_upload_field
            upload={@uploads.video_poster_image}
            label="Video Poster Image (Optional)"
            current_image={if @media_piece, do: @media_piece.video_poster_image}
            current_image_url={
              if @media_piece && @media_piece.video_poster_image,
                do:
                  QlariusWeb.Uploaders.VideoPoster.url(
                    {@media_piece.video_poster_image, @media_piece},
                    :original
                  )
            }
            accept_text="PNG, JPG, GIF, WEBP (max 10MB)"
            preview_size="w-64 h-auto"
            current_image_size="w-96 h-auto"
            current_image_class="w-full h-auto rounded-lg object-cover"
          />
        <% end %>
      </.panel>

      <.save_bar dirty={unsaved_changes?(@form, @uploads)}>
        <.link navigate={~p"/marketer/media"} class="btn btn-ghost">Cancel</.link>
        <.button phx-disable-with="Saving..." variant="primary">Save media piece</.button>
      </.save_bar>
    </.form>
    """
  end

  attr :value, :string, required: true
  attr :selected, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true

  defp media_type_option(assigns) do
    assigns = assign(assigns, :checked, assigns.value == assigns.selected)

    ~H"""
    <label class={[
      "flex cursor-pointer items-start gap-3 rounded-xl border p-4 transition-colors",
      @checked && "border-primary bg-primary/5",
      !@checked && "border-base-300 hover:border-base-content/30"
    ]}>
      <input
        type="radio"
        name="media_type"
        value={@value}
        class="radio radio-primary radio-sm mt-0.5"
        checked={@checked}
        phx-click="select_media_type"
        phx-value-type={@value}
      />
      <div class="min-w-0">
        <div class="flex items-center gap-2 text-sm font-semibold">
          <.icon name={@icon} class="size-4 text-base-content/60" />
          {@label}
        </div>
        <p class="mt-0.5 text-xs text-base-content/60">{@description}</p>
      </div>
    </label>
    """
  end

  attr :changeset, :any, required: true
  attr :media_piece, :map, required: true
  attr :uploads, :map, required: true
  attr :selected_media_type, :string, required: true

  defp ad_preview(assigns) do
    preview = Ecto.Changeset.apply_changes(assigns.changeset)

    pending_upload? =
      Enum.any?(
        [:banner_image, :video_file, :video_poster_image],
        &(assigns.uploads[&1].entries != [])
      )

    assigns =
      assign(assigns,
        preview: %{preview | title: preview.title || "Your ad title"},
        pending_upload?: pending_upload?
      )

    ~H"""
    <aside class="space-y-3 lg:sticky lg:top-22">
      <div class="flex items-baseline justify-between">
        <h2 class="text-sm font-semibold">Preview</h2>
        <span class="text-xs text-base-content/50">Updates as you type</span>
      </div>

      <%= if @selected_media_type == "three_tap" do %>
        <div class="space-y-4">
          <div>
            <p class="mb-1.5 text-xs font-medium text-base-content/60">Tap 1: banner</p>
            <.offer_frame>
              <div class="flex items-center justify-center bg-white" style="height: 115px;">
                <%= if @preview.banner_image do %>
                  <img
                    src={
                      QlariusWeb.Uploaders.ThreeTapBanner.url(
                        {@preview.banner_image, @preview},
                        :original
                      )
                    }
                    alt="Banner preview"
                    style="width: 345px; height: 115px;"
                  />
                <% else %>
                  <span class="text-sm text-gray-400">No banner yet</span>
                <% end %>
              </div>
              <:tap>TAP</:tap>
            </.offer_frame>
          </div>

          <div
            id="tap-2-preview"
            phx-hook="TextFitCheck"
            phx-mounted={JS.ignore_attributes(["data-clipped"])}
            class="group"
          >
            <p class="mb-1.5 text-xs font-medium text-base-content/60">Tap 2: text</p>
            <.offer_frame>
              <div data-fit-box class="overflow-hidden px-3 pt-2" style="height: 115px;">
                <div class="truncate text-lg font-bold text-blue-600 underline dark:text-blue-300">
                  {@preview.title}
                </div>
                <div class="mb-1 text-sm" style="line-height: 1.05rem">{@preview.body_copy}</div>
                <div class="text-xs text-green-500">{@preview.display_url}</div>
              </div>
              <:tap><.icon name="hero-check" class="size-4 text-green-500" /></:tap>
            </.offer_frame>
            <p class="mt-2 hidden items-center gap-1.5 text-xs text-warning group-data-[clipped]:flex">
              <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
              Text is cut off in the ad. Shorten the body copy so the display URL shows.
            </p>
          </div>
        </div>
      <% else %>
        <div class="rounded-2xl border border-base-300 bg-surface p-4 shadow-sm dark:bg-base-100">
          <div class="space-y-3">
            <div class="text-lg font-bold leading-tight text-blue-600 dark:text-blue-300">
              {@preview.title}
            </div>
            <%= if @media_piece.video_file do %>
              <.video_thumbnail
                media_piece={@media_piece}
                class="w-full"
                id={"mp-preview-#{@media_piece.id}"}
              />
            <% else %>
              <div class="flex aspect-video items-center justify-center rounded-lg bg-base-200 text-sm text-base-content/50">
                <.icon name="hero-film" class="mr-2 size-5" /> No video yet
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <p :if={@pending_upload?} class="text-xs text-base-content/50">
        New uploads appear in the preview after saving.
      </p>
    </aside>
    """
  end

  slot :inner_block, required: true
  slot :tap, required: true

  defp offer_frame(assigns) do
    ~H"""
    <div
      class="three-tap-offer-cover surface-panel-fill relative overflow-hidden rounded-md border border-gray-300 dark:border-gray-600"
      style="width: 347px; height: 152px;"
    >
      {render_slot(@inner_block)}
      <div class="absolute inset-x-0 bottom-0 flex text-xs font-light" style="height: 35px;">
        <div class="flex flex-1 items-center justify-center bg-base-200">{render_slot(@tap)}</div>
        <div class="flex flex-1 items-center justify-center border-l border-gray-300 bg-base-200 dark:border-gray-600">
          JUMP
        </div>
      </div>
    </div>
    """
  end

  defp unsaved_changes?(form, uploads) do
    form.source.changes != %{} or
      Enum.any?(
        Map.values(uploads),
        &match?(%Phoenix.LiveView.UploadConfig{entries: [_ | _]}, &1)
      )
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(_), do: "Unknown error"
end
