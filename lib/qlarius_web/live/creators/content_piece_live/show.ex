defmodule QlariusWeb.Creators.ContentPieceLive.Show do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentPiece, Creators}
  alias Qlarius.Tiqit.ContentAudiences
  alias QlariusWeb.AudienceCard
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Uploaders.CreatorImage

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    piece = Creators.get_content_piece!(id)
    group = piece.content_group
    catalog = group.catalog
    creator = catalog.creator

    {:ok,
     socket
     |> assign(:piece, piece)
     |> assign(:content_group, group)
     |> assign(:catalog, catalog)
     |> assign(:creator, creator)
     |> assign(:piece_hard_deletable, Creators.content_piece_hard_deletable?(piece))
     |> assign(:page_title, piece.title)
     |> assign(:audience, ContentAudiences.effective_audience(piece))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    piece = socket.assigns.piece
    group = piece.content_group

    case Creators.delete_content_piece(piece) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Content piece deleted successfully")
         |> push_navigate(to: ~p"/creators/content_groups/#{group.id}")}

      {:error, :requires_archive} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This piece cannot be deleted because it has purchase or ledger history. Use Archive instead."
         )}

      {:error, :already_archived} ->
        {:noreply, put_flash(socket, :error, "This content piece is already archived.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, "Delete failed: #{inspect(changeset.errors)}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Delete failed.")}
    end
  end

  def handle_event("archive", _params, socket) do
    case Creators.archive_content_piece(socket.assigns.piece) do
      {:ok, piece} ->
        {:noreply,
         socket
         |> assign(:piece, piece)
         |> assign(:piece_hard_deletable, Creators.content_piece_hard_deletable?(piece))
         |> put_flash(:info, "Content piece archived. It no longer appears in catalog lists.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not archive this content piece.")}
    end
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
            <.page class="max-w-7xl">
              <.page_header
                title={@piece.title}
                subtitle={"#{piece_label(@catalog)} in #{@content_group.title}"}
                crumbs={[
                  {@creator.name, ~p"/creators/#{@creator.id}"},
                  {@catalog.name, ~p"/creators/catalogs/#{@catalog.id}"},
                  {@content_group.title, ~p"/creators/content_groups/#{@content_group.id}"}
                ]}
              >
                <:badges>
                  <.status_badge :if={@piece.archived_at} tone="warning">Archived</.status_badge>
                </:badges>
                <:actions>
                  <.link
                    navigate={~p"/creators/content_pieces/#{@piece.id}/edit"}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-pencil-square" class="size-4" /> Edit
                  </.link>
                  <button
                    :if={is_nil(@piece.archived_at) && @piece_hard_deletable}
                    type="button"
                    phx-click="delete"
                    data-confirm={"Permanently delete this #{piece_label(@catalog, false)}? This cannot be undone."}
                    class="btn btn-ghost btn-sm text-error"
                  >
                    <.icon name="hero-trash" class="size-4" /> Delete
                  </button>
                  <button
                    :if={is_nil(@piece.archived_at) && !@piece_hard_deletable}
                    type="button"
                    phx-click="archive"
                    data-confirm={"Archive this #{piece_label(@catalog, false)}? It will be hidden from lists; purchase and ledger history stay intact."}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-archive-box" class="size-4" /> Archive
                  </button>
                </:actions>
              </.page_header>

              <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
                <div class="min-w-0 space-y-6">
                  <.panel id="piece-details" title="Details">
                    <img
                      :if={@piece.image}
                      src={CreatorImage.url({@piece.image, @piece}, :original)}
                      alt={@piece.title}
                      class="aspect-video w-full rounded-xl object-cover"
                    />
                    <p
                      :if={@piece.description not in [nil, ""]}
                      class="whitespace-pre-line text-sm leading-relaxed text-base-content/80 [overflow-wrap:anywhere]"
                    >
                      {@piece.description}
                    </p>
                    <p :if={@piece.description in [nil, ""]} class="text-sm text-base-content/50">
                      No description yet.
                    </p>
                    <dl class="grid gap-x-6 gap-y-4 border-t border-base-300 pt-4 sm:grid-cols-3">
                      <.detail_item label="Length" value={format_length(@piece.length)} />
                      <.detail_item label="Published" value={format_date(@piece.date_published)} />
                      <.detail_item
                        :if={ContentPiece.episode_label(@piece)}
                        label={piece_label(@catalog)}
                        value={ContentPiece.episode_label(@piece)}
                      />
                    </dl>
                  </.panel>

                  <.panel
                    id="piece-group"
                    title={Catalog.type_label(@catalog.group_type)}
                    description={"The #{Catalog.type_label(@catalog.group_type, 1, capitalize: false)} this #{piece_label(@catalog, false)} belongs to."}
                    flush
                  >
                    <div class="flex items-center gap-4 px-6 py-4">
                      <%= if ImageHelpers.group_image_url(@content_group) != ImageHelpers.placeholder_image_url() do %>
                        <img
                          src={ImageHelpers.group_image_url(@content_group)}
                          alt={@content_group.title}
                          class="size-12 shrink-0 rounded-lg object-cover"
                        />
                      <% else %>
                        <span class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-base-200 font-semibold text-base-content/70">
                          {String.first(@content_group.title || "?")}
                        </span>
                      <% end %>
                      <div class="min-w-0 flex-1">
                        <.link
                          navigate={~p"/creators/content_groups/#{@content_group.id}"}
                          class="block truncate font-semibold hover:underline"
                        >
                          {@content_group.title}
                        </.link>
                        <p
                          :if={@content_group.description not in [nil, ""]}
                          class="line-clamp-2 text-sm text-base-content/60"
                        >
                          {@content_group.description}
                        </p>
                      </div>
                      <.link
                        navigate={~p"/creators/content_groups/#{@content_group.id}"}
                        class="btn btn-sm"
                      >
                        Open
                      </.link>
                    </div>
                  </.panel>
                </div>

                <aside class="space-y-6 lg:sticky lg:top-6">
                  <.panel
                    id="piece-pricing"
                    title={"#{piece_label(@catalog)} pricing"}
                    description={"Buy just this #{piece_label(@catalog, false)}."}
                    flush
                  >
                    <:actions>
                      <.link
                        :if={@piece.tiqit_classes != []}
                        navigate={~p"/creators/content_pieces/#{@piece.id}/edit"}
                        class="btn btn-ghost btn-sm"
                      >
                        Edit prices
                      </.link>
                    </:actions>
                    <TiqitClassHTML.tiqit_classes_table
                      :if={@piece.tiqit_classes != []}
                      record={@piece}
                    />
                    <div
                      :if={@piece.tiqit_classes == []}
                      class="flex flex-col items-start gap-3 px-6 py-5"
                    >
                      <p class="text-sm text-base-content/60">
                        No prices yet. Add one so this {piece_label(@catalog, false)} can be bought on its own.
                      </p>
                      <.link
                        navigate={~p"/creators/content_pieces/#{@piece.id}/edit"}
                        class="btn btn-sm"
                      >
                        <.icon name="hero-plus" class="size-4" /> Set prices
                      </.link>
                    </div>
                  </.panel>

                  <AudienceCard.card
                    creator={@creator}
                    content={@piece}
                    effective={@audience}
                    level={:piece}
                    class={nil}
                  />

                  <.panel id="piece-info" title="Info">
                    <dl class="grid grid-cols-2 gap-x-6 gap-y-4">
                      <.detail_item label="Created" value={format_date(@piece.inserted_at)} />
                      <.detail_item label="Last updated" value={format_date(@piece.updated_at)} />
                      <.detail_item label="ID" value={"##{@piece.id}"} />
                    </dl>
                  </.panel>

                  <div
                    :if={@piece.archived_at}
                    id="piece-archived-note"
                    class="rounded-xl border border-warning/30 bg-warning/10 p-4 text-sm"
                  >
                    <p class="flex items-center gap-2 font-medium">
                      <.icon name="hero-archive-box" class="size-4 text-warning" />
                      Archived {format_date(@piece.archived_at)}
                    </p>
                    <p class="mt-1 text-base-content/70">
                      Removed from catalog and arcade lists. Existing access from past purchases is unchanged.
                    </p>
                  </div>
                </aside>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp piece_label(catalog, capitalize \\ true),
    do: Catalog.type_label(catalog.piece_type, 1, capitalize: capitalize)

  defp format_length(length) when length in [nil, 0], do: nil
  defp format_length(length), do: format_duration(length)

  defp format_date(nil), do: nil
  defp format_date(date), do: Calendar.strftime(date, "%b %-d, %Y")
end
