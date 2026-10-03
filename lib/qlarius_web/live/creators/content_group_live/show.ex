defmodule QlariusWeb.Creators.ContentGroupLive.Show do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.ContentAudiences
  alias QlariusWeb.AudienceCard
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.RssImporter
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias QlariusWeb.Creators.ContentGroupHTML
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.TiqitClassHTML
  import QlariusWeb.CoreComponents
  import QlariusWeb.Components.MarketerUI

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    content_group = Creators.get_content_group!(id)
    catalog = content_group.catalog
    creator = catalog.creator

    {:ok,
     socket
     |> assign(:content_group, content_group)
     |> assign(:catalog, catalog)
     |> assign(:creator, creator)
     |> assign(:page_title, content_group.title)
     |> assign(:piece_class_defaults, piece_class_defaults_from_group(content_group))
     |> assign(:piece_class_defaults_form_id, "piece-class-defaults-form")
     |> assign(:admin?, admin?(socket))
     |> assign(:feed_syncing?, false)
     |> assign(:audience, ContentAudiences.effective_audience(content_group))}
  end

  defp admin?(socket) do
    case socket.assigns[:current_scope] do
      %{true_user: %{role: "admin"}} -> true
      _ -> false
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    content_group = socket.assigns.content_group
    catalog = content_group.catalog

    {:ok, _content_group} = Creators.delete_content_group(content_group)

    {:noreply,
     socket
     |> put_flash(:info, "Content group deleted successfully")
     |> push_navigate(to: ~p"/creators/catalogs/#{catalog.id}")}
  end

  def handle_event("sync_feed", _params, %{assigns: %{admin?: true}} = socket) do
    group = socket.assigns.content_group

    {:noreply,
     socket
     |> assign(:feed_syncing?, true)
     |> start_async(:sync_feed, fn -> RssImporter.sync_group(group) end)}
  end

  def handle_event("toggle_feed_auto_sync", _params, %{assigns: %{admin?: true}} = socket) do
    group = socket.assigns.content_group

    case RssImporter.set_auto_sync(group, !group.feed_auto_sync) do
      {:ok, _group} ->
        {:noreply, assign(socket, :content_group, Creators.get_content_group!(group.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not change daily sync.")}
    end
  end

  def handle_event(event, _params, socket) when event in ~w(sync_feed toggle_feed_auto_sync),
    do: {:noreply, socket}

  def handle_event("add_default_tiqit_classes", _params, socket) do
    Arcade.write_default_group_tiqit_classes(socket.assigns.content_group)

    content_group = Creators.get_content_group!(socket.assigns.content_group.id)

    {:noreply,
     socket
     |> assign(:content_group, content_group)
     |> put_flash(:info, "Default Tiqit classes added successfully")}
  end

  def handle_event("delete_tiqit_class", %{"id" => id}, socket) do
    {:ok, _} = Creators.delete_tiqit_class(id)

    content_group = Creators.get_content_group!(socket.assigns.content_group.id)

    {:noreply,
     socket
     |> assign(:content_group, content_group)
     |> put_flash(:info, "Tiqit class deleted successfully")}
  end

  def handle_event("move_piece", %{"id" => id, "direction" => dir}, socket)
      when dir in ["up", "down"] do
    case Integer.parse(to_string(id)) do
      {piece_id, _} ->
        group = socket.assigns.content_group
        ordered = ContentGroup.ordered_content_pieces(group.content_pieces)
        idx = Enum.find_index(ordered, &(&1.id == piece_id))
        len = length(ordered)

        new_ordered =
          case {dir, idx} do
            {"up", i} when is_integer(i) and i > 0 -> swap_at(ordered, i, i - 1)
            {"down", i} when is_integer(i) and i < len - 1 -> swap_at(ordered, i, i + 1)
            _ -> ordered
          end

        if new_ordered == ordered do
          {:noreply, socket}
        else
          case Creators.restripe_content_pieces(group, new_ordered) do
            {:ok, g} -> {:noreply, assign(socket, :content_group, g)}
            {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update order.")}
          end
        end

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("move_piece", _params, socket), do: {:noreply, socket}

  def handle_event("update_piece_class_defaults", %{"defaults" => defaults} = params, socket) do
    socket = assign(socket, :piece_class_defaults, parse_piece_class_default_rows(defaults))

    case params["mode"] do
      mode when mode in ["overwrite", "fill_in"] ->
        apply_piece_class_defaults(socket, String.to_existing_atom(mode))

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("update_piece_class_defaults", _params, socket), do: {:noreply, socket}

  def handle_event("add_piece_class_default", _params, socket) do
    rows = socket.assigns.piece_class_defaults ++ [empty_piece_class_default_row()]

    {:noreply,
     socket
     |> assign(:piece_class_defaults, rows)
     |> refresh_piece_class_defaults_form()}
  end

  def handle_event("remove_piece_class_default", %{"index" => index}, socket) do
    case Integer.parse(to_string(index)) do
      {idx, _} ->
        rows = List.delete_at(socket.assigns.piece_class_defaults, idx)

        {:noreply,
         socket
         |> assign(:piece_class_defaults, rows)
         |> refresh_piece_class_defaults_form()}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "apply_piece_class_defaults",
        %{"defaults" => defaults, "mode" => mode},
        socket
      )
      when mode in ["overwrite", "fill_in"] do
    socket = assign(socket, :piece_class_defaults, parse_piece_class_default_rows(defaults))
    apply_piece_class_defaults(socket, String.to_existing_atom(mode))
  end

  def handle_event("apply_piece_class_defaults", _params, socket), do: {:noreply, socket}

  def handle_event(
        "apply_piece_order_preset",
        %{"preset" => "episode"},
        %{assigns: %{admin?: true, content_group: %{feed_url: url} = group}} = socket
      )
      when is_binary(url) and url != "" do
    {:noreply,
     socket
     |> assign(:feed_syncing?, true)
     |> start_async(:reorder_by_episode, fn -> RssImporter.reorder_by_episode(group) end)}
  end

  def handle_event("apply_piece_order_preset", params, socket) do
    preset = Map.get(params, "preset", "")

    if preset == "" or preset not in ContentGroup.piece_order_presets() do
      {:noreply, socket}
    else
      group = socket.assigns.content_group
      active = ContentGroup.active_content_pieces(group.content_pieces)
      sorted = ContentGroup.sort_pieces_by_preset(active, preset)

      case Creators.restripe_content_pieces(group, sorted) do
        {:ok, g} ->
          {:noreply,
           socket
           |> assign(:content_group, g)
           |> put_flash(
             :info,
             "Display order updated for all #{socket.assigns.catalog.piece_type}s."
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update order.")}
      end
    end
  end

  defp content_group_image_url(group) do
    ImageHelpers.group_image_url(group)
  end

  defp content_group_iframe_url(group) do
    Qlarius.Qlink.Urls.public_app_url("/widgets/arqade/group/#{group.id}")
  end

  defp swap_at(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp apply_piece_class_defaults(socket, mode) do
    group = socket.assigns.content_group
    pieces = ContentGroup.active_content_pieces(group.content_pieces)

    cond do
      pieces == [] ->
        {:noreply, put_flash(socket, :error, "Add content pieces before applying pricing.")}

      true ->
        case piece_class_default_specs(socket.assigns.piece_class_defaults) do
          [] ->
            {:noreply, put_flash(socket, :error, "Enter at least one duration and price.")}

          specs ->
            {:ok, kept_durations} =
              Arcade.write_default_piece_tiqit_classes(group, mode: mode, classes: specs)

            content_group = Creators.get_content_group!(group.id)

            piece_label =
              Catalog.type_label(socket.assigns.catalog.piece_type, 2, capitalize: false)

            socket =
              socket
              |> assign(:content_group, content_group)
              |> assign(
                :piece_class_defaults,
                Enum.map(specs, &piece_class_default_row/1)
              )
              |> refresh_piece_class_defaults_form()

            {:noreply, flash_piece_class_defaults(socket, mode, piece_label, kept_durations)}
        end
    end
  end

  defp piece_class_defaults_from_group(group) do
    first_with_classes =
      group.content_pieces
      |> ContentGroup.active_content_pieces()
      |> Enum.find(&(is_list(&1.tiqit_classes) and &1.tiqit_classes != []))

    specs =
      if first_with_classes do
        first_with_classes.tiqit_classes
        |> TiqitClass.order_by_duration_hours_asc()
        |> Enum.map(&%{duration_hours: &1.duration_hours, price: &1.price})
      else
        Arcade.default_piece_tiqit_class_specs()
      end

    Enum.map(specs, &piece_class_default_row/1)
  end

  defp piece_class_default_row(spec) do
    %{
      duration_hours: spec.duration_hours,
      price: spec.price |> to_string()
    }
  end

  defp empty_piece_class_default_row, do: %{duration_hours: nil, price: ""}

  defp flash_piece_class_defaults(socket, :fill_in, piece_label, _kept) do
    put_flash(socket, :info, "Filled in missing Tiqit classes on all #{piece_label}.")
  end

  defp flash_piece_class_defaults(socket, :overwrite, piece_label, []) do
    put_flash(socket, :info, "Overwrote Tiqit pricing on all #{piece_label}.")
  end

  defp flash_piece_class_defaults(socket, :overwrite, piece_label, kept_durations) do
    kept =
      kept_durations
      |> Enum.map(&TiqitClassHTML.format_tiqit_class_duration/1)
      |> Enum.join(", ")

    put_flash(
      socket,
      :error,
      "Updated pricing on all #{piece_label}, but could not remove #{kept} because purchased tiqits still use #{if length(kept_durations) == 1, do: "that class", else: "those classes"}."
    )
  end

  defp refresh_piece_class_defaults_form(socket) do
    assign(
      socket,
      :piece_class_defaults_form_id,
      "piece-class-defaults-form-#{System.unique_integer([:positive])}"
    )
  end

  defp parse_piece_class_default_rows(defaults) when is_map(defaults) do
    defaults
    |> Enum.sort_by(fn {key, _} ->
      case Integer.parse(to_string(key)) do
        {idx, _} -> idx
        :error -> 0
      end
    end)
    |> Enum.map(fn {_key, row} ->
      hours =
        case Integer.parse(to_string(row["duration_hours"] || "")) do
          {value, _} -> value
          :error -> nil
        end

      %{duration_hours: hours, price: row["price"] || ""}
    end)
  end

  defp piece_class_default_specs(rows) do
    rows
    |> Enum.flat_map(fn row ->
      price = parse_price(row.price)

      if is_integer(row.duration_hours) and row.duration_hours > 0 and price do
        [%{duration_hours: row.duration_hours, price: price}]
      else
        []
      end
    end)
  end

  defp parse_price(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.replace(",", "")
    |> case do
      "" ->
        nil

      trimmed ->
        case Decimal.parse(trimmed) do
          {decimal, ""} -> decimal
          _ -> nil
        end
    end
  end

  @impl true
  def handle_async(:sync_feed, {:ok, {:ok, detail}}, socket) do
    %{created: created, updated: updated} = detail.counts

    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> assign(:content_group, Creators.get_content_group!(socket.assigns.content_group.id))
     |> put_flash(:info, "Feed synced: #{created} new, #{updated} updated.")}
  end

  def handle_async(:sync_feed, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> put_flash(:error, "Feed sync failed: #{sync_error_text(reason)}")}
  end

  def handle_async(:reorder_by_episode, {:ok, {:ok, _detail}}, socket) do
    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> assign(:content_group, Creators.get_content_group!(socket.assigns.content_group.id))
     |> put_flash(:info, "Renumbered from the feed and put in episode order.")}
  end

  def handle_async(:reorder_by_episode, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> put_flash(:error, "Could not reorder: #{sync_error_text(reason)}")}
  end

  def handle_async(:reorder_by_episode, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> put_flash(:error, "Reorder crashed: #{inspect(reason)}")}
  end

  def handle_async(:sync_feed, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:feed_syncing?, false)
     |> put_flash(:error, "Feed sync crashed: #{inspect(reason)}")}
  end

  defp sync_error_text(reason) when is_binary(reason), do: reason

  defp sync_error_text(reason) when is_atom(reason),
    do: String.replace(to_string(reason), "_", " ")

  defp sync_error_text(reason), do: inspect(reason)

  defp feed_scope_label(group) do
    season = if group.feed_season, do: "Season #{group.feed_season}", else: "All seasons"

    types =
      case group.feed_episode_types do
        [_ | _] = types -> Enum.join(types, ", ")
        _ -> Enum.join(RssImporter.default_episode_types(), ", ")
      end

    "#{season} · #{types}"
  end

  defp format_synced_at(nil), do: "never"
  defp format_synced_at(%DateTime{} = at), do: Calendar.strftime(at, "%b %-d, %Y %H:%M UTC")

  defp duration_hint(hours) when is_integer(hours) and hours > 0 do
    label = TiqitClassHTML.format_tiqit_class_duration(hours)
    if String.ends_with?(label, ["hour", "hours"]), do: nil, else: label
  end

  defp duration_hint(_hours), do: nil

  @impl true
  def render(assigns) do
    pieces = ContentGroup.ordered_content_pieces(assigns.content_group.content_pieces)
    catalog = assigns.catalog

    assigns =
      assign(assigns,
        pieces: pieces,
        unpriced_count: Enum.count(pieces, &(&1.tiqit_classes == [])),
        piece_label: Catalog.type_label(catalog.piece_type, 1),
        piece_word: Catalog.type_label(catalog.piece_type, 1, capitalize: false),
        pieces_title: Catalog.type_label(catalog.piece_type, 2),
        pieces_word: Catalog.type_label(catalog.piece_type, 2, capitalize: false),
        group_label: Catalog.type_label(catalog.group_type, 1),
        group_word: Catalog.type_label(catalog.group_type, 1, capitalize: false)
      )

    ~H"""
    <div>
      <Layouts.admin {assigns}>
        <div class="flex h-screen">
          <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

          <div class="flex min-w-0 grow flex-col">
            <AdminTopbar.topbar current_user={@current_scope.user} />

            <div class="overflow-auto">
              <.page class="max-w-7xl">
                <.page_header
                  title={@content_group.title}
                  subtitle={"#{@group_label} in #{@catalog.name}"}
                  crumbs={[
                    {@creator.name, ~p"/creators/#{@creator.id}"},
                    {@catalog.name, ~p"/creators/catalogs/#{@catalog.id}"}
                  ]}
                >
                  <:actions>
                    <.link
                      navigate={~p"/creators/content_groups/#{@content_group.id}/preview"}
                      class="btn btn-ghost btn-sm"
                    >
                      <.icon name="hero-eye" class="size-4" /> Preview
                    </.link>
                    <.link
                      navigate={~p"/creators/content_groups/#{@content_group.id}/edit"}
                      class="btn btn-ghost btn-sm"
                    >
                      <.icon name="hero-pencil-square" class="size-4" /> Edit
                    </.link>
                    <button
                      type="button"
                      phx-click="delete"
                      data-confirm={"Are you sure you want to delete this #{@group_word}?"}
                      class="btn btn-ghost btn-sm text-error"
                    >
                      <.icon name="hero-trash" class="size-4" /> Delete
                    </button>
                  </:actions>
                </.page_header>

                <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
                  <div class="min-w-0 space-y-8">
                    <section id="content-pieces">
                      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                        <div class="flex items-center gap-2">
                          <h2 class="text-base font-semibold">{@pieces_title}</h2>
                          <span class="rounded-full bg-base-200 px-2.5 py-0.5 text-xs font-medium text-base-content/70">
                            {length(@pieces)}
                          </span>
                        </div>
                        <div class="flex flex-wrap items-center gap-2">
                          <button
                            :if={@pieces != []}
                            type="button"
                            phx-click={show_modal("piece-order-modal")}
                            class="btn btn-ghost btn-sm"
                          >
                            <.icon name="hero-arrows-up-down" class="size-4" /> Display order
                          </button>
                          <details class="dropdown dropdown-end">
                            <summary class="btn btn-ghost btn-sm">
                              <.icon name="hero-arrow-down-tray" class="size-4" /> Import
                              <.icon name="hero-chevron-down" class="size-3.5" />
                            </summary>
                            <ul class="dropdown-content menu z-20 mt-1 w-52 rounded-box border border-base-300 bg-base-100 p-1 shadow-sm">
                              <li>
                                <.link
                                  navigate={
                                    ~p"/creators/content_groups/#{@content_group.id}/youtube_import"
                                  }
                                  title="Import from YouTube"
                                >
                                  <.icon name="hero-play-circle" class="size-4" /> From YouTube
                                </.link>
                              </li>
                              <li :if={@admin?}>
                                <.link
                                  navigate={
                                    ~p"/creators/content_groups/#{@content_group.id}/rss_import"
                                  }
                                  title="Import from RSS"
                                >
                                  <.icon name="hero-rss" class="size-4" /> From RSS
                                </.link>
                              </li>
                            </ul>
                          </details>
                          <.link
                            navigate={
                              ~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"
                            }
                            class="btn btn-primary btn-sm"
                          >
                            <.icon name="hero-plus" class="size-4" /> New {@piece_word}
                          </.link>
                        </div>
                      </div>

                      <.panel flush>
                        <.empty_state
                          :if={@pieces == []}
                          icon="hero-queue-list"
                          title={"No #{@pieces_word} yet"}
                        >
                          Add your first {@piece_word}, or import a batch from YouTube.
                          <:action>
                            <div class="flex flex-wrap justify-center gap-2">
                              <.link
                                navigate={
                                  ~p"/creators/content_groups/#{@content_group.id}/content_pieces/new"
                                }
                                class="btn btn-primary btn-sm"
                              >
                                <.icon name="hero-plus" class="size-4" /> New {@piece_word}
                              </.link>
                              <.link
                                navigate={
                                  ~p"/creators/content_groups/#{@content_group.id}/youtube_import"
                                }
                                class="btn btn-ghost btn-sm"
                              >
                                <.icon name="hero-play-circle" class="size-4" /> Import from YouTube
                              </.link>
                              <.link
                                :if={@admin?}
                                navigate={
                                  ~p"/creators/content_groups/#{@content_group.id}/rss_import"
                                }
                                class="btn btn-ghost btn-sm"
                              >
                                <.icon name="hero-rss" class="size-4" /> Import from RSS
                              </.link>
                            </div>
                          </:action>
                        </.empty_state>

                        <ul :if={@pieces != []} class="divide-y divide-base-300">
                          <li
                            :for={piece <- @pieces}
                            id={"content-piece-#{piece.id}"}
                            class="flex gap-4 px-6 py-4 transition-colors hover:bg-base-200/40"
                          >
                            <img
                              :if={@content_group.show_piece_thumbnails}
                              src={ImageHelpers.content_image_url(piece, @content_group)}
                              alt=""
                              class="w-20 shrink-0 self-start rounded-lg object-cover"
                            />
                            <div class="min-w-0 flex-1 space-y-1.5">
                              <.link
                                navigate={~p"/creators/content_pieces/#{piece.id}"}
                                class="block font-medium hover:underline"
                              >
                                {piece.title}
                              </.link>
                              <p class="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-base-content/50">
                                <span
                                  :if={ContentPiece.episode_label(piece)}
                                  class="font-medium text-base-content/70"
                                >
                                  {ContentPiece.episode_label(piece)}
                                </span>
                                <span class="inline-flex items-center gap-1">
                                  <.icon name="hero-calendar" class="size-3" />
                                  {Calendar.strftime(piece.inserted_at, "%b %d, %Y")}
                                </span>
                                <span
                                  :if={piece.length not in [nil, 0]}
                                  class="inline-flex items-center gap-1"
                                >
                                  <.icon name="hero-clock" class="size-3" />
                                  {format_duration(piece.length)}
                                </span>
                              </p>
                              <TiqitClassHTML.price_chips tiqit_classes={piece.tiqit_classes} />
                              <div
                                :if={@content_group.show_piece_descriptions && piece.description}
                                class="description-container pt-1"
                                id={"desc-#{piece.id}"}
                              >
                                {ContentGroupHTML.piece_description_p_tag(piece.description)}
                                <button
                                  type="button"
                                  onclick={"toggleDescription(document.getElementById('desc-#{piece.id}'))"}
                                  class="expand-btn mt-1 cursor-pointer text-xs font-medium text-base-content/60 hover:text-base-content"
                                >
                                  Expand
                                </button>
                              </div>
                            </div>
                            <div class="flex shrink-0 items-center gap-1 self-start">
                              <.icon_button
                                icon="hero-eye"
                                label="View"
                                navigate={~p"/creators/content_pieces/#{piece.id}"}
                              />
                              <.icon_button
                                icon="hero-pencil-square"
                                label="Edit"
                                navigate={~p"/creators/content_pieces/#{piece.id}/edit"}
                              />
                            </div>
                          </li>
                        </ul>
                      </.panel>
                    </section>

                    <form
                      id={@piece_class_defaults_form_id}
                      phx-change="update_piece_class_defaults"
                      phx-submit="apply_piece_class_defaults"
                    >
                      <.panel
                        id="piece-pricing"
                        title={"#{@piece_label} pricing"}
                        description={"A template of durations and prices you can apply to every #{@piece_word} in this #{@group_word} at once."}
                      >
                        <ul class="space-y-2 text-sm text-base-content/70">
                          <li class="flex gap-2">
                            <.icon
                              name="hero-plus-circle"
                              class="mt-0.5 size-4 shrink-0 text-base-content/40"
                            />
                            <span>
                              <span class="font-medium text-base-content">Fill in missing</span>
                              adds these prices only to {@pieces_word} that don't have that duration yet. Existing prices stay as they are.
                            </span>
                          </li>
                          <li class="flex gap-2">
                            <.icon
                              name="hero-arrow-path"
                              class="mt-0.5 size-4 shrink-0 text-base-content/40"
                            />
                            <span>
                              <span class="font-medium text-base-content">Overwrite all</span>
                              makes every {@piece_word} match this list: matching durations get the new price and other durations are removed. Durations that buyers already hold tiqits for are kept.
                            </span>
                          </li>
                        </ul>

                        <div
                          :if={@unpriced_count > 0}
                          class="flex items-start gap-2 rounded-xl border border-warning/30 bg-warning/10 p-4 text-sm"
                        >
                          <.icon
                            name="hero-exclamation-triangle"
                            class="mt-0.5 size-4 shrink-0 text-warning"
                          />
                          <span>
                            {@unpriced_count} {Catalog.type_label(
                              @catalog.piece_type,
                              @unpriced_count,
                              capitalize: false
                            )} {if @unpriced_count == 1, do: "has", else: "have"} no pricing yet. Fill in missing will add this template to them.
                          </span>
                        </div>

                        <div class="max-w-lg overflow-hidden rounded-xl border border-base-300">
                          <div class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2rem] gap-3 border-b border-base-300 bg-base-200/40 px-4 py-2 text-xs font-medium text-base-content/60">
                            <span>Duration (hours)</span>
                            <span>Price</span>
                            <span class="sr-only">Remove</span>
                          </div>
                          <div class="divide-y divide-base-300">
                            <div
                              :for={{row, idx} <- Enum.with_index(@piece_class_defaults)}
                              class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_2rem] items-center gap-3 px-4 py-2"
                            >
                              <label class="input input-sm w-full">
                                <input
                                  type="number"
                                  name={"defaults[#{idx}][duration_hours]"}
                                  value={row.duration_hours}
                                  min="1"
                                  placeholder="24"
                                  aria-label="Duration in hours"
                                  class="grow"
                                />
                                <span
                                  :if={duration_hint(row.duration_hours)}
                                  class="text-xs text-base-content/50"
                                >
                                  {duration_hint(row.duration_hours)}
                                </span>
                              </label>
                              <label class="input input-sm w-full">
                                <span class="text-base-content/50">$</span>
                                <input
                                  type="text"
                                  name={"defaults[#{idx}][price]"}
                                  value={row.price}
                                  inputmode="decimal"
                                  placeholder="0.75"
                                  aria-label="Price in dollars"
                                  class="grow"
                                />
                              </label>
                              <button
                                type="button"
                                phx-click="remove_piece_class_default"
                                phx-value-index={idx}
                                class="btn btn-ghost btn-xs btn-square text-error"
                                aria-label="Remove default class"
                                title="Remove"
                              >
                                <.icon name="hero-x-mark" class="size-4" />
                              </button>
                            </div>
                          </div>
                          <p
                            :if={@piece_class_defaults == []}
                            class="px-4 py-3 text-sm text-base-content/50"
                          >
                            No durations yet. Add one to build the template.
                          </p>
                        </div>

                        <p :if={@pieces == []} class="text-xs text-base-content/50">
                          Add {@pieces_word} before applying pricing.
                        </p>

                        <:footer>
                          <button
                            type="button"
                            phx-click="add_piece_class_default"
                            class="btn btn-ghost btn-sm mr-auto"
                          >
                            <.icon name="hero-plus" class="size-4" /> Add duration
                          </button>
                          <button
                            type="submit"
                            name="mode"
                            value="fill_in"
                            class="btn btn-primary btn-sm order-last"
                            disabled={@pieces == []}
                          >
                            Fill in missing
                          </button>
                          <button
                            type="submit"
                            name="mode"
                            value="overwrite"
                            data-confirm={"Overwrite existing #{@piece_word} prices to match these defaults? Classes not in this grid will be removed from every #{@piece_word}."}
                            class="btn btn-sm"
                            disabled={@pieces == []}
                          >
                            Overwrite all {@pieces_word}
                          </button>
                        </:footer>
                      </.panel>
                    </form>
                  </div>

                  <aside class="space-y-6 lg:sticky lg:top-6">
                    <.panel id="group-overview">
                      <img
                        src={content_group_image_url(@content_group)}
                        alt={@content_group.title}
                        class="aspect-square w-full rounded-xl object-cover"
                      />
                      <div
                        :if={
                          ContentGroupHTML.piece_list_description(@content_group.description) != ""
                        }
                        class="description-container"
                        id="group-description"
                      >
                        {ContentGroupHTML.piece_description_p_tag(@content_group.description)}
                        <button
                          type="button"
                          onclick="toggleDescription(document.getElementById('group-description'))"
                          class="expand-btn mt-1 cursor-pointer text-xs font-medium text-base-content/60 hover:text-base-content"
                        >
                          Expand
                        </button>
                      </div>
                      <p
                        :if={
                          ContentGroupHTML.piece_list_description(@content_group.description) == ""
                        }
                        class="text-sm text-base-content/50"
                      >
                        No description yet.
                      </p>
                      <dl class="grid grid-cols-2 gap-x-6 gap-y-4">
                        <.detail_item label={@pieces_title} value={length(@pieces)} />
                        <.detail_item label="Without pricing" value={@unpriced_count} />
                        <.detail_item label={Catalog.type_label(@catalog.type, 1)}>
                          <.link
                            navigate={~p"/creators/catalogs/#{@catalog.id}"}
                            class="hover:underline"
                          >
                            {@catalog.name}
                          </.link>
                        </.detail_item>
                      </dl>
                    </.panel>

                    <.panel
                      id="group-pricing"
                      flush
                      title={"#{@group_label} pass"}
                      description={"Access to every #{@piece_word} in this #{@group_word} for a set time."}
                    >
                      <TiqitClassHTML.tiqit_classes_table
                        :if={@content_group.tiqit_classes != []}
                        record={@content_group}
                        on_delete="delete_tiqit_class"
                      />
                      <div
                        :if={@content_group.tiqit_classes == []}
                        class="flex flex-col items-start gap-3 px-6 py-5"
                      >
                        <p class="text-sm text-base-content/60">
                          No {@group_word} pass prices yet.
                        </p>
                        <button
                          type="button"
                          phx-click="add_default_tiqit_classes"
                          class="btn btn-sm"
                        >
                          <.icon name="hero-plus" class="size-4" /> Add default prices
                        </button>
                      </div>
                    </.panel>

                    <AudienceCard.card
                      creator={@creator}
                      content={@content_group}
                      effective={@audience}
                      level={:group}
                      class={nil}
                    />

                    <.panel
                      :if={@pieces != []}
                      id="group-embed"
                      title="Embed"
                      description={"Put this URL in an iframe to show this #{@group_word} on your site."}
                    >
                      <:actions>
                        <.link
                          navigate={~p"/creators/content_groups/#{@content_group.id}/preview"}
                          class="btn btn-ghost btn-sm"
                        >
                          <.icon name="hero-eye" class="size-4" /> Preview
                        </.link>
                      </:actions>
                      <div
                        class="group relative cursor-pointer rounded-lg border border-base-300 bg-base-200/40 p-3 transition-colors hover:bg-base-200"
                        onclick="copyCode(this)"
                        title="Click to copy"
                      >
                        <div class="flex items-start gap-3">
                          <code class="min-w-0 flex-1 break-all font-mono text-xs">
                            {content_group_iframe_url(@content_group)}
                          </code>
                          <.icon
                            name="hero-document-duplicate"
                            class="size-4 shrink-0 text-base-content/50 group-hover:text-base-content"
                          />
                        </div>
                        <div class="copy-notification absolute -top-2 -right-2 hidden rounded bg-success px-2 py-1 text-xs text-success-content shadow">
                          Copied!
                        </div>
                      </div>
                    </.panel>

                    <.panel
                      :if={@content_group.feed_url}
                      id="podcast-feed"
                      title="Podcast feed"
                      description={"#{@pieces_title} imported from this RSS feed."}
                    >
                      <dl class="grid gap-4">
                        <.detail_item label="Feed URL">
                          <span class="break-all">{@content_group.feed_url}</span>
                        </.detail_item>
                        <.detail_item label="Scope" value={feed_scope_label(@content_group)} />
                        <.detail_item
                          label="Last synced"
                          value={format_synced_at(@content_group.last_synced_at)}
                        />
                      </dl>
                      <:footer :if={@admin?}>
                        <label class="mr-auto flex cursor-pointer items-center gap-2 text-sm">
                          <input
                            type="checkbox"
                            class="toggle toggle-primary toggle-sm"
                            checked={@content_group.feed_auto_sync}
                            phx-click="toggle_feed_auto_sync"
                          /> Daily sync
                        </label>
                        <button
                          type="button"
                          phx-click="sync_feed"
                          class="btn btn-ghost btn-sm"
                          disabled={@feed_syncing?}
                        >
                          <%= if @feed_syncing? do %>
                            <span class="loading loading-spinner loading-xs"></span> Syncing…
                          <% else %>
                            <.icon name="hero-arrow-path" class="size-4" /> Sync now
                          <% end %>
                        </button>
                      </:footer>
                    </.panel>
                  </aside>
                </div>
              </.page>
            </div>
          </div>
        </div>
      </Layouts.admin>

      <.modal
        id="piece-order-modal"
        on_cancel={hide_modal("piece-order-modal")}
        panel_class="w-[min(100%,32rem)]"
      >
        <div class="px-6 pt-6 pr-14 pb-4">
          <h2 id="piece-order-modal-title" class="text-base font-semibold">
            {@piece_label} display order
          </h2>
          <p id="piece-order-modal-description" class="mt-1 text-sm text-base-content/60">
            Use the arrows to move one {@piece_word} at a time, or pick a sort to reorder every {@piece_word} in this {@group_word}.
          </p>
        </div>

        <div class="space-y-4 px-6 pb-6">
          <form phx-change="apply_piece_order_preset">
            <label
              for="piece-order-preset"
              class="mb-1.5 flex items-center gap-2 text-xs font-medium text-base-content/60"
            >
              Reorder all by
              <span :if={@feed_syncing?} class="loading loading-spinner loading-xs"></span>
            </label>
            <select id="piece-order-preset" name="preset" class="select select-sm w-full">
              <option value="">Choose…</option>
              <option value="episode">Episode order (trailer, then Ep 1, 2, 3…)</option>
              <option value="desc">Newest first (by date added)</option>
              <option value="asc">Oldest first (by date added)</option>
              <option value="title_asc">Title A–Z</option>
              <option value="title_desc">Title Z–A</option>
            </select>
          </form>

          <ol class="max-h-[min(24rem,55vh)] divide-y divide-base-300 overflow-y-auto rounded-xl border border-base-300">
            <li
              :for={{piece, idx} <- Enum.with_index(@pieces)}
              class="flex items-center gap-3 px-3 py-1.5"
            >
              <span class="w-6 shrink-0 text-right text-xs text-base-content/40">{idx + 1}</span>
              <span class="min-w-0 flex-1 truncate text-sm" title={piece.title}>
                {piece.title}
              </span>
              <div class="flex shrink-0 items-center gap-0.5">
                <button
                  type="button"
                  phx-click="move_piece"
                  phx-value-id={piece.id}
                  phx-value-direction="up"
                  disabled={idx == 0}
                  class="btn btn-ghost btn-xs btn-square disabled:opacity-30"
                  aria-label="Move up"
                  title="Move up"
                >
                  <.icon name="hero-chevron-up" class="size-4" />
                </button>
                <button
                  type="button"
                  phx-click="move_piece"
                  phx-value-id={piece.id}
                  phx-value-direction="down"
                  disabled={idx == length(@pieces) - 1}
                  class="btn btn-ghost btn-xs btn-square disabled:opacity-30"
                  aria-label="Move down"
                  title="Move down"
                >
                  <.icon name="hero-chevron-down" class="size-4" />
                </button>
              </div>
            </li>
          </ol>
        </div>

        <div class="flex justify-end border-t border-base-300 bg-base-200/40 px-6 py-4">
          <button type="button" phx-click={hide_modal("piece-order-modal")} class="btn btn-sm">
            Done
          </button>
        </div>
      </.modal>

      <script type="text/javascript">
        function copyCode(element) {
          navigator.clipboard.writeText(element.querySelector('code').textContent.trim());
          const notification = element.querySelector('.copy-notification');
          notification.classList.remove('hidden');
          setTimeout(() => notification.classList.add('hidden'), 2000);
        }

        window.toggleDescription = function(container) {
          const text = container.querySelector('.description-text');
          const btn = container.querySelector('.expand-btn');
          
          if (text.classList.contains('line-clamp-3')) {
            text.classList.remove('line-clamp-3');
            btn.textContent = 'Collapse';
          } else {
            text.classList.add('line-clamp-3');
            btn.textContent = 'Expand';
          }
        };
      </script>
    </div>
    """
  end
end
