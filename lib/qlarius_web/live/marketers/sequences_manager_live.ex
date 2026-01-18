defmodule QlariusWeb.Live.Marketers.SequencesManagerLive do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Sponster.Campaigns.MediaSequences
  alias Qlarius.Sponster.Ads
  alias QlariusWeb.Live.Marketers.CurrentMarketer

  on_mount {CurrentMarketer, :load_current_marketer}

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
    if socket.assigns.current_marketer do
      media_sequences =
        MediaSequences.list_media_sequences_for_marketer(socket.assigns.current_marketer.id)

      archived_media_sequences =
        MediaSequences.list_archived_media_sequences_for_marketer(
          socket.assigns.current_marketer.id
        )

      media_pieces = Ads.list_active_media_pieces_for_marketer(socket.assigns.current_marketer.id)

      socket
      |> assign(:media_sequences, media_sequences)
      |> assign(:archived_media_sequences, archived_media_sequences)
      |> assign(:media_pieces, media_pieces)
      |> assign(:selected_media_piece_id, nil)
      |> assign(:is_video_type, false)
      |> assign(:show_archived, false)
      |> assign_default_form()
    else
      socket
      |> assign(:media_sequences, [])
      |> assign(:archived_media_sequences, [])
      |> assign(:media_pieces, [])
      |> assign(:selected_media_piece_id, nil)
      |> assign(:is_video_type, false)
      |> assign(:show_archived, false)
      |> assign_default_form()
    end
  end

  defp assign_default_form(socket) do
    assign(
      socket,
      :sequence_form,
      to_form(%{
        "frequency" => "3",
        "frequency_buffer_hours" => "24",
        "maximum_banner_count" => "3",
        "banner_retry_buffer_hours" => "10",
        "title" => ""
      })
    )
  end

  @impl true
  def handle_event("update_form", %{"sequence" => params}, socket) do
    media_piece_id = params["media_piece_id"]

    if media_piece_id && media_piece_id != "" do
      media_piece = Ads.get_media_piece!(media_piece_id)
      is_video = media_piece.media_piece_type_id == 2

      updated_title =
        MediaSequences.generate_sequence_name(
          media_piece,
          params["frequency"] || "3",
          params["frequency_buffer_hours"] || "24",
          params["maximum_banner_count"] || "3",
          params["banner_retry_buffer_hours"] || "10"
        )

      form = to_form(Map.put(params, "title", updated_title))

      {:noreply,
       socket
       |> assign(:selected_media_piece_id, String.to_integer(media_piece_id))
       |> assign(:is_video_type, is_video)
       |> assign(:sequence_form, form)}
    else
      form = to_form(params)

      {:noreply,
       socket
       |> assign(:selected_media_piece_id, nil)
       |> assign(:is_video_type, false)
       |> assign(:sequence_form, form)}
    end
  end

  @impl true
  def handle_event("create_sequence", %{"sequence" => params}, socket) do
    if !socket.assigns.current_marketer do
      {:noreply, put_flash(socket, :error, "Please select a marketer first")}
    else
      if !params["media_piece_id"] do
        {:noreply, put_flash(socket, :error, "Please select a media piece")}
      else
        case MediaSequences.create_media_sequence_with_run(
               socket.assigns.current_marketer.id,
               params
             ) do
          {:ok, _sequence} ->
            {:noreply,
             socket
             |> put_flash(:info, "Media sequence created successfully")
             |> assign_sequences_data()}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to create sequence")
             |> assign(:sequence_form, to_form(changeset))}
        end
      end
    end
  end

  @impl true
  def handle_event("delete_sequence", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      sequence =
        MediaSequences.get_media_sequence_for_marketer!(
          id,
          socket.assigns.current_marketer.id
        )

      case MediaSequences.delete_media_sequence(sequence) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Media sequence deleted successfully")
           |> assign_sequences_data()}

        {:error, :sequence_in_use} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Cannot delete sequence that is in use by active campaigns. Archive it instead."
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete sequence")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("archive_sequence", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      sequence =
        MediaSequences.get_media_sequence_for_marketer!(
          id,
          socket.assigns.current_marketer.id
        )

      case MediaSequences.archive_media_sequence(sequence) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Media sequence archived successfully")
           |> assign_sequences_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to archive sequence")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("unarchive_sequence", %{"id" => id}, socket) do
    if socket.assigns.current_marketer do
      sequence =
        MediaSequences.get_media_sequence_for_marketer!(
          id,
          socket.assigns.current_marketer.id
        )

      case MediaSequences.unarchive_media_sequence(sequence) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Media sequence unarchived successfully")
           |> assign_sequences_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to unarchive sequence")}
      end
    else
      {:noreply, put_flash(socket, :error, "No marketer selected")}
    end
  end

  @impl true
  def handle_event("toggle_archived", _params, socket) do
    {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}
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

            <div :if={!@current_marketer} class="p-6">
              <div class="alert alert-warning">
                <.icon name="hero-exclamation-circle" class="w-6 h-6" />
                <span>Please select a marketer to manage media sequences.</span>
              </div>
            </div>

            <div :if={@current_marketer} class="p-6">
              <div class="flex justify-between items-center mb-6">
                <h1 class="text-2xl font-bold">Media Sequencer</h1>
              </div>

              <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div class="lg:col-span-2">
                  <div :if={@media_sequences == []} class="card bg-base-100 border border-base-300">
                    <div class="card-body text-center py-12">
                      <.icon
                        name="hero-document-plus"
                        class="w-16 h-16 mx-auto text-base-content/30 mb-4"
                      />
                      <p class="text-lg font-medium text-base-content/70">No media sequences yet</p>
                      <p class="text-sm text-base-content/50 mt-2">
                        Create your first sequence on the right to get started
                      </p>
                    </div>
                  </div>

                  <.sequences_table
                    :if={@media_sequences != []}
                    sequences={@media_sequences}
                    archived={false}
                  />

                  <div
                    :if={@archived_media_sequences != []}
                    class="mt-8 border-t border-base-300 pt-6"
                  >
                    <button phx-click="toggle_archived" class="btn btn-ghost btn-sm mb-4">
                      <.icon
                        name={if @show_archived, do: "hero-chevron-down", else: "hero-chevron-right"}
                        class="w-4 h-4"
                      /> Archived Sequences ({length(@archived_media_sequences)})
                    </button>

                    <.sequences_table
                      :if={@show_archived}
                      sequences={@archived_media_sequences}
                      archived={true}
                    />
                  </div>
                </div>

                <div class="lg:col-span-1">
                  <div class="card bg-base-100 border border-base-300">
                    <div class="card-body">
                      <h2 class="card-title mb-4">Create New Sequence</h2>

                      <%= if @media_pieces == [] do %>
                        <div class="alert alert-warning">
                          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                          <span class="text-sm">
                            No active media pieces. Create media pieces first.
                          </span>
                        </div>
                      <% else %>
                        <.form
                          for={@sequence_form}
                          phx-submit="create_sequence"
                          phx-change="update_form"
                          class="space-y-4"
                        >
                          <div class="form-control w-full">
                            <label class="label">
                              <span class="label-text font-semibold">1. Select Media Piece</span>
                            </label>
                            <select
                              name="sequence[media_piece_id]"
                              class="select select-bordered w-full"
                              required
                            >
                              <option value="">Choose a media piece...</option>
                              <option
                                :for={piece <- @media_pieces}
                                value={piece.id}
                                selected={piece.id == @selected_media_piece_id}
                              >
                                {piece.title}
                              </option>
                            </select>
                          </div>

                          <div class="divider text-sm">2. Frequency Rules</div>

                          <div class="form-control w-full">
                            <label class="label">
                              <span class="label-text">Frequency</span>
                            </label>
                            <input
                              type="number"
                              name="sequence[frequency]"
                              value={@sequence_form.params["frequency"]}
                              class="input input-bordered w-full"
                              min="1"
                              required
                            />
                            <label class="label">
                              <span class="label-text-alt text-base-content/60 text-xs">
                                Desired completions
                              </span>
                            </label>
                          </div>

                          <div class="form-control w-full">
                            <label class="label">
                              <span class="label-text">Frequency Buffer (hours)</span>
                            </label>
                            <input
                              type="number"
                              name="sequence[frequency_buffer_hours]"
                              value={@sequence_form.params["frequency_buffer_hours"]}
                              class="input input-bordered w-full"
                              min="1"
                              required
                            />
                            <label class="label">
                              <span class="label-text-alt text-base-content/60 text-xs">
                                Hours between completions
                              </span>
                            </label>
                          </div>

                          <%= if !@is_video_type do %>
                            <div class="form-control w-full">
                              <label class="label">
                                <span class="label-text">Maximum Banner Attempts</span>
                              </label>
                              <input
                                type="number"
                                name="sequence[maximum_banner_count]"
                                value={@sequence_form.params["maximum_banner_count"]}
                                class="input input-bordered w-full"
                                min="1"
                                required
                              />
                              <label class="label">
                                <span class="label-text-alt text-base-content/60 text-xs">
                                  Max banners without completion
                                </span>
                              </label>
                            </div>

                            <div class="form-control w-full">
                              <label class="label">
                                <span class="label-text">Banner Retry Buffer (hours)</span>
                              </label>
                              <input
                                type="number"
                                name="sequence[banner_retry_buffer_hours]"
                                value={@sequence_form.params["banner_retry_buffer_hours"]}
                                class="input input-bordered w-full"
                                min="1"
                                required
                              />
                              <label class="label">
                                <span class="label-text-alt text-base-content/60 text-xs">
                                  Hours between banner retries
                                </span>
                              </label>
                            </div>
                          <% end %>

                          <div class="divider text-sm">3. Name</div>

                          <div class="form-control w-full">
                            <input
                              type="text"
                              name="sequence[title]"
                              value={@sequence_form.params["title"]}
                              placeholder="Sequence name"
                              class="input input-bordered w-full"
                              required
                            />
                            <label class="label">
                              <span class="label-text-alt text-base-content/60 text-xs">
                                Auto-generated, but you can customize it
                              </span>
                            </label>
                          </div>

                          <button
                            type="submit"
                            class="btn btn-primary w-full"
                            disabled={!@selected_media_piece_id}
                          >
                            <.icon name="hero-plus" class="w-5 h-5" /> Create Sequence
                          </button>
                        </.form>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp sequence_has_active_campaigns?(sequence) do
    Enum.any?(sequence.campaigns, fn campaign ->
      is_nil(campaign.deactivated_at)
    end)
  end

  attr :sequences, :list, required: true
  attr :archived, :boolean, required: true

  defp sequences_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class={["table", !@archived && "table-zebra"]}>
        <thead>
          <tr>
            <th>Sequence Name</th>
            <th>Media Piece</th>
            <th class="text-center">Rules</th>
            <th class="text-center">{if @archived, do: "Actions", else: ""}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={sequence <- @sequences} class={@archived && "opacity-60"}>
            <td class="font-medium !align-top">{sequence.title}</td>
            <td class="!align-top">
              <%= if sequence.media_runs != [] do %>
                <% media_run = List.first(sequence.media_runs) %>
                <div class="flex flex-col items-start">
                  <%= if media_run.media_piece.banner_image do %>
                    <img
                      src={
                        QlariusWeb.Uploaders.ThreeTapBanner.url(
                          {media_run.media_piece.banner_image, media_run.media_piece},
                          :original
                        )
                      }
                      alt={media_run.media_piece.title}
                      class="h-10 w-auto max-w-[200px] object-contain rounded border border-base-300"
                    />
                  <% end %>
                  <span>{media_run.media_piece.title}</span>
                </div>
              <% end %>
            </td>
            <td class="text-sm !align-top">
              <%= if sequence.media_runs != [] do %>
                <% media_run = List.first(sequence.media_runs) %>
                <% is_video = media_run.media_piece.media_piece_type_id == 2 %>
                <div class="space-y-1">
                  <div>Frequency: {media_run.frequency}/{media_run.frequency_buffer_hours}h</div>
                  <%= if !is_video do %>
                    <div>
                      Banner: {media_run.maximum_banner_count}/{media_run.banner_retry_buffer_hours}h
                    </div>
                  <% end %>
                </div>
              <% end %>
            </td>
            <td class="text-center !align-top">
              <%= if @archived do %>
                <button
                  phx-click="unarchive_sequence"
                  phx-value-id={sequence.id}
                  class="btn btn-sm btn-success btn-outline"
                >
                  Unarchive
                </button>
              <% else %>
                <%= if sequence_has_active_campaigns?(sequence) do %>
                  <button
                    phx-click="archive_sequence"
                    phx-value-id={sequence.id}
                    class="btn btn-sm btn-warning btn-outline"
                    data-confirm="Archive this sequence? It is currently in use."
                  >
                    Archive
                  </button>
                <% else %>
                  <button
                    phx-click="delete_sequence"
                    phx-value-id={sequence.id}
                    class="btn btn-sm btn-error btn-outline"
                    data-confirm="Delete this sequence? This cannot be undone."
                  >
                    Delete
                  </button>
                <% end %>
              <% end %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
