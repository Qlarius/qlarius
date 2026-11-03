defmodule QlariusWeb.Admin.PromoSequenceLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Sponster.{PromoSequence, PromoSequences}
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Promo sequences")
     |> allow_upload(:wide, accept: ~w(.png .svg), max_entries: 1, auto_upload: true)
     |> allow_upload(:narrow, accept: ~w(.png .svg), max_entries: 1, auto_upload: true)
     |> allow_upload(:bounce, accept: ~w(.png .svg), max_entries: 1, auto_upload: true)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Promo sequences")
    |> assign(:sequences, PromoSequences.list_sequences())
  end

  defp apply_action(socket, :new, _params) do
    changeset = PromoSequences.change_sequence(%PromoSequence{max_height: 80})

    socket
    |> assign(:page_title, "New promo sequence")
    |> assign(:sequence, nil)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    sequence = PromoSequences.get_sequence!(id)

    socket
    |> assign(:page_title, sequence.name)
    |> assign(:sequence, sequence)
    |> assign(:form, to_form(PromoSequences.change_sequence(sequence)))
  end

  @impl true
  def handle_event("validate", %{"promo_sequence" => params}, socket) do
    changeset =
      (socket.assigns.sequence || %PromoSequence{})
      |> PromoSequences.change_sequence(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("save", %{"promo_sequence" => params}, socket) do
    case save_sequence(socket.assigns.sequence, params) do
      {:ok, sequence} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sequence saved.")
         |> push_navigate(to: ~p"/admin/promo_sequences/#{sequence}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("add_slide", %{"track" => track}, socket) do
    upload_name = if track == "wide", do: :wide, else: :narrow

    case consume_image(socket, upload_name) do
      {socket, {:ok, filename}} ->
        case PromoSequences.add_slide(socket.assigns.sequence, %{
               "track" => track,
               "image" => filename
             }) do
          {:ok, _slide} ->
            {:noreply, reload(socket, "Slide added.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_text(reason))}
        end

      {socket, :empty} ->
        {:noreply, put_flash(socket, :error, "Choose a PNG or SVG.")}

      {socket, {:error, reason}} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("delete_slide", %{"id" => id}, socket) do
    sequence = socket.assigns.sequence

    case PromoSequences.get_slide(sequence, id) do
      {:ok, slide} ->
        case PromoSequences.delete_slide(slide) do
          {:ok, _} -> {:noreply, reload(socket, "Slide removed.")}
          {:error, reason} -> {:noreply, put_flash(socket, :error, error_text(reason))}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("move_slide", %{"id" => id, "dir" => dir}, socket) do
    sequence = socket.assigns.sequence

    with {:ok, slide} <- PromoSequences.get_slide(sequence, id),
         {:ok, ids} <- swapped_ids(sequence, slide, dir),
         {:ok, _} <- PromoSequences.reorder(sequence, slide.track, ids) do
      {:noreply, reload(socket, nil)}
    else
      :edge -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("save_bounce", _params, socket) do
    case consume_image(socket, :bounce) do
      {socket, {:ok, filename}} ->
        case PromoSequences.update_sequence(socket.assigns.sequence, %{"bounce_image" => filename}) do
          {:ok, _} -> {:noreply, reload(socket, "Bounce image saved.")}
          {:error, reason} -> {:noreply, put_flash(socket, :error, error_text(reason))}
        end

      {socket, :empty} ->
        {:noreply, put_flash(socket, :error, "Choose a PNG or SVG.")}

      {socket, {:error, reason}} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("clear_bounce", _params, socket) do
    case PromoSequences.update_sequence(socket.assigns.sequence, %{"bounce_image" => nil}) do
      {:ok, _} -> {:noreply, reload(socket, "Bounce image cleared.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  def handle_event("delete", _params, socket) do
    case PromoSequences.delete_sequence(socket.assigns.sequence) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sequence deleted.")
         |> push_navigate(to: ~p"/admin/promo_sequences")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_text(reason))}
    end
  end

  defp save_sequence(nil, params) do
    PromoSequences.create_sequence(params)
  end

  defp save_sequence(sequence, params) do
    PromoSequences.update_sequence(sequence, params)
  end

  defp consume_image(socket, name) do
    results =
      consume_uploaded_entries(socket, name, fn meta, entry ->
        upload = %Plug.Upload{
          path: meta.path,
          filename: entry.client_name,
          content_type: entry.client_type
        }

        {:ok, PromoSequences.store_upload(upload)}
      end)

    case results do
      [{:ok, filename}] -> {socket, {:ok, filename}}
      [{:error, reason}] -> {socket, {:error, reason}}
      [] -> {socket, :empty}
    end
  end

  defp swapped_ids(sequence, slide, dir) do
    ids =
      sequence.slides
      |> Enum.filter(&(&1.track == slide.track))
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.id)

    index = Enum.find_index(ids, &(&1 == slide.id))
    swap = if dir == "up", do: index - 1, else: index + 1

    if swap in 0..(length(ids) - 1) do
      other = Enum.at(ids, swap)
      {:ok, ids |> List.replace_at(index, other) |> List.replace_at(swap, Enum.at(ids, index))}
    else
      :edge
    end
  end

  defp reload(socket, nil) do
    sequence = PromoSequences.get_sequence!(socket.assigns.sequence.id)

    socket
    |> assign(:sequence, sequence)
    |> assign(:form, to_form(PromoSequences.change_sequence(sequence)))
  end

  defp reload(socket, message) do
    socket
    |> put_flash(:info, message)
    |> reload(nil)
  end

  defp error_text(%Ecto.Changeset{}), do: "Check the sequence fields and try again."
  defp error_text(:default_required), do: "Mark another sequence as the default first."

  defp error_text(:default_sequence),
    do: "Mark another sequence as the default before deleting this one."

  defp error_text(:invalid_track), do: "Track must be wide or narrow."
  defp error_text({:upload_failed, _field, message}), do: message
  defp error_text(reason), do: "Could not save (#{inspect(reason)})."

  defp bounce_src(%{bounce_image: image}) when is_binary(image) and image != "" do
    PromoSequences.image_url(image)
  end

  defp bounce_src(_sequence), do: "/images/sponster_us_quarter.png"

  defp track_slides(slides, track) do
    slides
    |> Enum.filter(&(&1.track == track))
    |> Enum.sort_by(& &1.position)
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
            <%= if @live_action == :index do %>
              <.index sequences={@sequences} />
            <% else %>
              <.editor
                live_action={@live_action}
                form={@form}
                sequence={assigns[:sequence]}
                uploads={@uploads}
              />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp index(assigns) do
    ~H"""
    <.page class="max-w-5xl">
      <.page_header title="Promo sequences" subtitle="Banner sets for the embed carousel.">
        <:actions>
          <.link navigate={~p"/admin/promo_sequences/new"} class="btn btn-primary btn-sm">
            New sequence
          </.link>
        </:actions>
      </.page_header>

      <.panel flush>
        <div class="divide-y divide-base-300">
          <div :for={sequence <- @sequences} class="flex items-center justify-between gap-3 px-4 py-3">
            <div class="min-w-0">
              <.link
                navigate={~p"/admin/promo_sequences/#{sequence}"}
                class="font-medium hover:underline"
              >
                {sequence.name}
              </.link>
              <div class="mt-1 flex flex-wrap gap-1">
                <span :if={sequence.global} class="badge badge-sm badge-ghost">Global</span>
                <span :if={sequence.is_default} class="badge badge-sm badge-primary">Default</span>
              </div>
            </div>
            <span class="text-sm text-base-content/60">{sequence.max_height}px</span>
          </div>
        </div>
      </.panel>
    </.page>
    """
  end

  defp editor(assigns) do
    ~H"""
    <.page class="max-w-6xl">
      <.page_header
        title={if @live_action == :new, do: "New promo sequence", else: @sequence.name}
        subtitle="Wide and narrow tracks share one max height."
        back_to={~p"/admin/promo_sequences"}
        back_label="Promo sequences"
      />

      <.panel>
        <.form for={@form} phx-change="validate" phx-submit="save" id="promo-sequence-form">
          <.input field={@form[:name]} label="Name" />
          <.input field={@form[:max_height]} type="number" label="Max height (px)" min="1" max="400" />
          <.input field={@form[:global]} type="checkbox" label="Global catalog" />
          <.input field={@form[:is_default]} type="checkbox" label="Default for new recipients" />
          <div class="mt-4 flex justify-end">
            <button type="submit" class="btn btn-primary">Save sequence</button>
          </div>
        </.form>
      </.panel>

      <%= if @sequence do %>
        <.panel class="mt-6">
          <h2 class="mb-3 font-semibold">Bounce image</h2>
          <p class="mb-3 text-sm text-base-content/70">
            Shown in the spinning bounce behind the bar. Clear a custom image to use the quarter.
          </p>
          <div class="mb-3 flex h-20 w-20 items-end justify-center overflow-hidden rounded border border-base-300 bg-base-100">
            <img
              src={bounce_src(@sequence)}
              alt="Bounce image"
              class="h-auto max-h-full w-auto max-w-full object-contain object-bottom"
            />
          </div>
          <form phx-change="validate_upload" phx-submit="save_bounce" id="promo-bounce-form">
            <.live_file_input upload={@uploads.bounce} class="file-input file-input-bordered w-full" />
            <div class="mt-3 flex gap-2">
              <button type="submit" class="btn btn-primary btn-sm">Save bounce image</button>
              <button
                :if={@sequence.bounce_image}
                type="button"
                phx-click="clear_bounce"
                class="btn btn-ghost btn-sm"
              >
                Clear
              </button>
            </div>
          </form>
        </.panel>

        <.track_editor
          :for={track <- ["wide", "narrow"]}
          track={track}
          slides={track_slides(@sequence.slides, track)}
          upload={if(track == "wide", do: @uploads.wide, else: @uploads.narrow)}
          max_height={@sequence.max_height}
        />

        <div class="mt-6">
          <button
            type="button"
            phx-click="delete"
            data-confirm="Delete this sequence?"
            class="btn btn-ghost btn-sm text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Delete sequence
          </button>
        </div>
      <% end %>
    </.page>
    """
  end

  defp track_editor(assigns) do
    ~H"""
    <.panel class="mt-6">
      <h2 class="mb-1 font-semibold">{if @track == "wide", do: "Wide", else: "Narrow"} track</h2>
      <p class="mb-3 text-sm text-base-content/70">{track_tip(@track, @max_height)}</p>
      <p :if={@slides == []} class="mb-3 text-sm text-base-content/70">
        Empty tracks show the built-in banners.
      </p>
      <ol class="mb-4 space-y-4">
        <li :for={slide <- @slides} class="flex items-end gap-3">
          <div
            class={[
              "relative shrink-0",
              if(@track == "wide", do: "w-[500px]", else: "w-[216px]")
            ]}
            style={"padding-top: #{max(@max_height - 50, 0)}px"}
          >
            <div class="relative h-[50px] rounded border border-base-300 bg-base-100">
              <img
                src={PromoSequences.image_url(slide.image)}
                alt=""
                class="absolute bottom-0 left-0 h-auto w-auto max-w-full object-contain object-bottom"
                style={"max-height: #{@max_height}px"}
              />
            </div>
          </div>
          <div class="flex shrink-0 items-center gap-0.5">
            <button
              type="button"
              phx-click="move_slide"
              phx-value-id={slide.id}
              phx-value-dir="up"
              class="btn btn-ghost btn-sm btn-square"
              aria-label="Move up"
              title="Move up"
            >
              <.icon name="hero-chevron-up" class="size-5" />
            </button>
            <button
              type="button"
              phx-click="move_slide"
              phx-value-id={slide.id}
              phx-value-dir="down"
              class="btn btn-ghost btn-sm btn-square"
              aria-label="Move down"
              title="Move down"
            >
              <.icon name="hero-chevron-down" class="size-5" />
            </button>
            <button
              type="button"
              phx-click="delete_slide"
              phx-value-id={slide.id}
              data-confirm="Remove this slide?"
              class="btn btn-ghost btn-sm btn-square text-error"
              aria-label="Remove slide"
              title="Remove"
            >
              <.icon name="hero-trash" class="size-5" />
            </button>
          </div>
        </li>
      </ol>
      <form phx-change="validate_upload" phx-submit="add_slide" id={"promo-#{@track}-form"}>
        <input type="hidden" name="track" value={@track} />
        <.live_file_input upload={@upload} class="file-input file-input-bordered w-full" />
        <button type="submit" class="btn btn-sm mt-3">Add image</button>
      </form>
    </.panel>
    """
  end

  # Banner slot on the 50px bar. Wide is the capped max-w-3xl row: px-4,
  # two gap-2 gutters, a 126px logo, and a 94px Info button leave 500px.
  # Narrow is a 390px phone, where the logo collapses to 32px and leaves 216px.
  defp track_tip("wide", height), do: "500px by up to #{height}px"

  defp track_tip("narrow", height), do: "216px by up to #{height}px"
end
