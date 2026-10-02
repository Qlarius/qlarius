defmodule QlariusWeb.Live.Marketers.SequencesManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Sponster.Campaigns.MediaSequences
  alias Qlarius.Sponster.Ads
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

  @default_params %{
    "media_piece_id" => "",
    "frequency" => "3",
    "frequency_buffer_hours" => "24",
    "maximum_banner_count" => "3",
    "banner_retry_buffer_hours" => "10",
    "title" => ""
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> assign(:page_title, "Sequences")
      |> assign_sequences_data()

    {:noreply, socket}
  end

  defp assign_sequences_data(socket) do
    {media_sequences, archived_media_sequences, media_pieces} =
      if socket.assigns.current_marketer do
        marketer_id = socket.assigns.current_marketer.id

        {MediaSequences.list_media_sequences_for_marketer(marketer_id),
         MediaSequences.list_archived_media_sequences_for_marketer(marketer_id),
         Ads.list_active_media_pieces_for_marketer(marketer_id)}
      else
        {[], [], []}
      end

    socket
    |> assign(:media_sequences, media_sequences)
    |> assign(:archived_media_sequences, archived_media_sequences)
    |> assign(:media_pieces, media_pieces)
    |> assign(:show_archived, false)
    |> assign_form(@default_params)
  end

  defp assign_form(socket, params) do
    media_piece = find_media_piece(socket.assigns.media_pieces, params["media_piece_id"])

    socket
    |> assign(:sequence_form, to_form(params, as: :sequence))
    |> assign(:selected_media_piece, media_piece)
    |> assign(:auto_title, auto_title(media_piece, params))
  end

  defp find_media_piece(media_pieces, id) when is_binary(id) and id != "" do
    Enum.find(media_pieces, &(to_string(&1.id) == id))
  end

  defp find_media_piece(_media_pieces, _id), do: nil

  defp auto_title(nil, _params), do: ""

  defp auto_title(media_piece, params) do
    MediaSequences.generate_sequence_name(
      media_piece,
      params["frequency"],
      params["frequency_buffer_hours"],
      params["maximum_banner_count"],
      params["banner_retry_buffer_hours"]
    )
  end

  @impl true
  def handle_event("update_form", %{"sequence" => params}, socket) do
    params = Map.merge(@default_params, params)
    media_piece = find_media_piece(socket.assigns.media_pieces, params["media_piece_id"])
    title_untouched? = params["title"] in ["", socket.assigns.auto_title]

    params =
      if title_untouched?,
        do: Map.put(params, "title", auto_title(media_piece, params)),
        else: params

    {:noreply, assign_form(socket, params)}
  end

  def handle_event("create_sequence", %{"sequence" => params} = all_params, socket) do
    cond do
      !socket.assigns.current_marketer ->
        {:noreply, put_flash(socket, :error, "Please select a marketer first")}

      params["media_piece_id"] in [nil, ""] ->
        {:noreply, put_flash(socket, :error, "Please select a media piece")}

      true ->
        case MediaSequences.create_media_sequence_with_run(
               socket.assigns.current_marketer.id,
               params
             ) do
          {:ok, _sequence} ->
            socket = put_flash(socket, :info, "Media sequence created successfully")

            case all_params["return_to"] do
              nil ->
                {:noreply, assign_sequences_data(socket)}

              return_to ->
                {:noreply,
                 push_navigate(socket,
                   to: safe_return_to(return_to, ~p"/marketer/sequences")
                 )}
            end

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to create sequence. Check the rules and name.")
             |> assign_form(Map.merge(@default_params, params))}
        end
    end
  end

  def handle_event("delete_sequence", %{"id" => id}, socket) do
    with_sequence(socket, id, fn sequence ->
      case MediaSequences.delete_media_sequence(sequence) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Media sequence deleted successfully")
          |> assign_sequences_data()

        {:error, :sequence_in_use} ->
          put_flash(
            socket,
            :error,
            "Cannot delete sequence that is in use by active campaigns. Archive it instead."
          )

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete sequence")
      end
    end)
  end

  def handle_event("archive_sequence", %{"id" => id}, socket) do
    with_sequence(socket, id, fn sequence ->
      case MediaSequences.archive_media_sequence(sequence) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Media sequence archived successfully")
          |> assign_sequences_data()

        {:error, _} ->
          put_flash(socket, :error, "Failed to archive sequence")
      end
    end)
  end

  def handle_event("unarchive_sequence", %{"id" => id}, socket) do
    with_sequence(socket, id, fn sequence ->
      case MediaSequences.unarchive_media_sequence(sequence) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Media sequence unarchived successfully")
          |> assign_sequences_data()

        {:error, _} ->
          put_flash(socket, :error, "Failed to unarchive sequence")
      end
    end)
  end

  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
  end

  defp with_sequence(socket, id, fun) do
    if socket.assigns.current_marketer do
      sequence =
        MediaSequences.get_media_sequence_for_marketer!(id, socket.assigns.current_marketer.id)

      {:noreply, fun.(sequence)}
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  defp form_dirty?(form) do
    Map.take(form.params, Map.keys(@default_params)) != @default_params
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.current_marketer_bar
              current_marketer={@current_marketer}
              current_path={~p"/marketer/sequences"}
            />

            <.no_marketer_notice
              :if={!@current_marketer}
              message="Choose a marketer to manage their media sequences."
            />

            <.page :if={@current_marketer}>
              <.page_header
                title="Media sequences"
                count={length(@media_sequences)}
                subtitle="Pair a media piece with delivery rules. Campaigns run their ads through a sequence."
              />

              <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_380px]">
                <div class="min-w-0">
                  <.panel flush>
                    <.empty_state
                      :if={@media_sequences == []}
                      icon="hero-numbered-list"
                      title="No media sequences yet"
                    >
                      Pick a media piece and set its rules in the form to create your first sequence.
                    </.empty_state>
                    <.sequence_list
                      :if={@media_sequences != []}
                      sequences={@media_sequences}
                      archived={false}
                    />
                  </.panel>

                  <.archived_section
                    label="Archived sequences"
                    count={length(@archived_media_sequences)}
                    open={@show_archived}
                    toggle="toggle_archived"
                  >
                    <.panel flush>
                      <.sequence_list sequences={@archived_media_sequences} archived={true} />
                    </.panel>
                  </.archived_section>
                </div>

                <.new_sequence_form
                  form={@sequence_form}
                  media_pieces={@media_pieces}
                  selected_media_piece={@selected_media_piece}
                />
              </div>
            </.page>

            <.unsaved_changes_dialog message="Your new sequence has not been created yet. Create it before you leave?" />
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :media_pieces, :list, required: true
  attr :selected_media_piece, :any, required: true

  defp new_sequence_form(assigns) do
    assigns =
      assign(
        assigns,
        :is_video,
        match?(%{media_piece_type_id: 2}, assigns.selected_media_piece)
      )

    ~H"""
    <div class="lg:sticky lg:top-22">
      <.panel
        :if={@media_pieces == []}
        title="New sequence"
        description="Sequences need an active media piece."
      >
        <.empty_state icon="hero-photo" title="No active media pieces">
          Create a media piece first, then come back to sequence it.
          <:action>
            <.link navigate={~p"/marketer/media/new"} class="btn btn-primary btn-sm">
              New media piece
            </.link>
          </:action>
        </.empty_state>
      </.panel>

      <.form
        :if={@media_pieces != []}
        for={@form}
        id="new-sequence-form"
        phx-change="update_form"
        phx-submit="create_sequence"
        phx-hook="UnsavedChanges"
        data-dirty={to_string(form_dirty?(@form))}
        data-dialog="unsaved-changes-dialog"
      >
        <.panel title="New sequence" description="Choose an ad, then decide how often people see it.">
          <.step number={1} title="Media piece">
            <.input
              type="select"
              name="sequence[media_piece_id]"
              value={@form.params["media_piece_id"]}
              prompt="Choose a media piece"
              options={Enum.map(@media_pieces, &{&1.title, &1.id})}
              required
            />
            <p
              :if={@selected_media_piece}
              class="flex items-center gap-1.5 text-xs text-base-content/60"
            >
              <.icon
                name={if @is_video, do: "hero-play-circle", else: "hero-photo"}
                class="size-4"
              />
              {if @is_video, do: "Video ad", else: "3-tap banner ad"}
            </p>
          </.step>

          <.step number={2} title="Delivery rules">
            <div class="grid grid-cols-2 gap-x-3">
              <.input
                type="number"
                name="sequence[frequency]"
                value={@form.params["frequency"]}
                label="Completions"
                description="Times each person finishes the ad"
                min="1"
                required
              />
              <.input
                type="number"
                name="sequence[frequency_buffer_hours]"
                value={@form.params["frequency_buffer_hours"]}
                label="Hours between"
                description="Wait before the next completion"
                min="1"
                required
              />
              <%= if !@is_video do %>
                <.input
                  type="number"
                  name="sequence[maximum_banner_count]"
                  value={@form.params["maximum_banner_count"]}
                  label="Banner attempts"
                  description="Banners shown without a completion"
                  min="1"
                  required
                />
                <.input
                  type="number"
                  name="sequence[banner_retry_buffer_hours]"
                  value={@form.params["banner_retry_buffer_hours"]}
                  label="Retry hours"
                  description="Wait before showing the banner again"
                  min="1"
                  required
                />
              <% end %>
            </div>
          </.step>

          <.step number={3} title="Name">
            <.input
              type="text"
              name="sequence[title]"
              value={@form.params["title"]}
              placeholder="Sequence name"
              description="Filled in for you. Edit it to use your own name."
              required
            />
          </.step>

          <:footer>
            <.unsaved_note dirty={form_dirty?(@form)} id="unsaved-changes-note" />
            <.button
              variant="primary"
              phx-disable-with="Creating..."
              disabled={is_nil(@selected_media_piece)}
            >
              <.icon name="hero-plus" class="size-4" /> Create sequence
            </.button>
          </:footer>
        </.panel>
      </.form>
    </div>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex items-center gap-2">
        <span class="flex size-5 items-center justify-center rounded-full bg-base-200 text-xs font-semibold text-base-content/70">
          {@number}
        </span>
        <h3 class="text-sm font-semibold">{@title}</h3>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp sequence_has_active_campaigns?(sequence) do
    Enum.any?(sequence.campaigns, &is_nil(&1.deactivated_at))
  end

  attr :sequences, :list, required: true
  attr :archived, :boolean, required: true

  defp sequence_list(assigns) do
    ~H"""
    <ul class="divide-y divide-base-300">
      <li
        :for={sequence <- @sequences}
        id={"sequence-#{sequence.id}"}
        class={[
          "flex items-center gap-5 px-6 py-4 transition-colors hover:bg-base-200/40",
          @archived && "opacity-70"
        ]}
      >
        <% media_run = List.first(sequence.media_runs) %>
        <% is_video = media_run && media_run.media_piece.media_piece_type_id == 2 %>

        <div class="w-32 shrink-0">
          <%= cond do %>
            <% media_run && media_run.media_piece.banner_image -> %>
              <img
                src={
                  QlariusWeb.Uploaders.ThreeTapBanner.url(
                    {media_run.media_piece.banner_image, media_run.media_piece},
                    :original
                  )
                }
                alt=""
                class="aspect-[3/1] w-full rounded-md border border-base-300 bg-white object-cover"
              />
            <% true -> %>
              <div class="flex aspect-[3/1] w-full items-center justify-center rounded-md bg-base-200">
                <.icon
                  name={if is_video, do: "hero-play-circle", else: "hero-photo"}
                  class="size-5 text-base-content/40"
                />
              </div>
          <% end %>
        </div>

        <div class="min-w-0 flex-1">
          <p class="truncate font-semibold">{sequence.title}</p>
          <p :if={media_run} class="mt-0.5 truncate text-sm text-base-content/60">
            {media_run.media_piece.title}
          </p>
          <div :if={media_run} class="mt-2 flex flex-wrap gap-1.5">
            <.chip>
              {media_run.frequency} completions, {media_run.frequency_buffer_hours}h apart
            </.chip>
            <.chip :if={!is_video}>
              {media_run.maximum_banner_count} banner attempts, retry after {media_run.banner_retry_buffer_hours}h
            </.chip>
          </div>
        </div>

        <div class="shrink-0">
          <%= cond do %>
            <% @archived -> %>
              <button
                type="button"
                phx-click="unarchive_sequence"
                phx-value-id={sequence.id}
                class="btn btn-sm btn-ghost"
              >
                <.icon name="hero-arrow-uturn-left" class="size-4" /> Unarchive
              </button>
            <% sequence_has_active_campaigns?(sequence) -> %>
              <button
                type="button"
                phx-click="archive_sequence"
                phx-value-id={sequence.id}
                class="btn btn-sm btn-ghost"
                data-confirm="Archive this sequence? It is used by an active campaign."
              >
                <.icon name="hero-archive-box" class="size-4" /> Archive
              </button>
            <% true -> %>
              <button
                type="button"
                phx-click="delete_sequence"
                phx-value-id={sequence.id}
                class="btn btn-sm btn-ghost btn-square text-error"
                aria-label={"Delete #{sequence.title}"}
                data-confirm="Delete this sequence? This cannot be undone."
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
          <% end %>
        </div>
      </li>
    </ul>
    """
  end
end
