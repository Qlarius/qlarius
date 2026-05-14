defmodule QlariusWeb.Creators.ContentGroupLive.YoutubeImport do
  @moduledoc """
  Wizard for importing YouTube channel or playlist videos as
  `ContentPiece`s into an existing `%ContentGroup{}`.

  Flow: `:channel` → `:review` → `:confirm` → `:importing` → `:done`.

  The target ContentGroup is fixed by the route (`:content_group_id`)
  and pre-existing tiqit_classes on the parent catalog are the
  precondition; per-piece tiers are seeded automatically during
  import.
  """

  use QlariusWeb, :live_view

  import Ecto.Query

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentPiece, Creators, TiqitClass, YoutubeImporter}

  @impl true
  def mount(%{"content_group_id" => id}, _session, socket) do
    content_group = Creators.get_content_group!(id)
    catalog = content_group.catalog
    creator = catalog.creator

    socket =
      socket
      |> assign(
        content_group: content_group,
        catalog: catalog,
        creator: creator,
        page_title: "Import YouTube videos",
        wizard_step: :channel,
        channel_input: "",
        channel_preview: nil,
        channel_error: nil,
        videos: [],
        filter: "",
        selected_video_ids: MapSet.new(),
        existing_youtube_ids: MapSet.new(),
        progress: 0,
        progress_total: 0,
        import_results: nil,
        catalog_pricing_ok?: catalog_has_active_tiqit_class?(catalog)
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("lookup", %{"channel_input" => input}, socket) when is_binary(input) do
    socket =
      socket
      |> assign(channel_input: input, channel_error: nil)
      |> start_async(:lookup, fn -> YoutubeImporter.fetch_import_preview(input) end)

    {:noreply, socket}
  end

  def handle_event("back_to_channel", _params, socket) do
    {:noreply,
     assign(socket,
       wizard_step: :channel,
       channel_preview: nil,
       videos: [],
       filter: "",
       selected_video_ids: MapSet.new()
     )}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, assign(socket, filter: "")}
  end

  def handle_event("back_to_review", _params, socket) do
    {:noreply, assign(socket, wizard_step: :review)}
  end

  def handle_event("toggle_video", %{"id" => yt_id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_video_ids, yt_id) do
        MapSet.delete(socket.assigns.selected_video_ids, yt_id)
      else
        MapSet.put(socket.assigns.selected_video_ids, yt_id)
      end

    {:noreply, assign(socket, selected_video_ids: selected)}
  end

  def handle_event("toggle_all", _params, socket) do
    visible_selectable =
      socket.assigns.videos
      |> filtered_videos(socket.assigns.filter)
      |> Enum.reject(fn v ->
        MapSet.member?(socket.assigns.existing_youtube_ids, v.youtube_id)
      end)
      |> Enum.map(& &1.youtube_id)
      |> MapSet.new()

    currently_selected = socket.assigns.selected_video_ids
    all_visible_selected? = MapSet.subset?(visible_selectable, currently_selected)

    new_selected =
      if all_visible_selected? do
        # Deselect just the visible ones; preserve any selections outside the filter.
        MapSet.difference(currently_selected, visible_selectable)
      else
        MapSet.union(currently_selected, visible_selectable)
      end

    {:noreply, assign(socket, selected_video_ids: new_selected)}
  end

  def handle_event("continue_to_confirm", _params, socket) do
    if MapSet.size(socket.assigns.selected_video_ids) == 0 do
      {:noreply, put_flash(socket, :error, "Select at least one video to import.")}
    else
      {:noreply, assign(socket, wizard_step: :confirm)}
    end
  end

  def handle_event("start_import", _params, socket) do
    content_group = socket.assigns.content_group

    selected_videos =
      Enum.filter(socket.assigns.videos, fn v ->
        MapSet.member?(socket.assigns.selected_video_ids, v.youtube_id)
      end)

    total = length(selected_videos)
    parent = self()

    socket =
      socket
      |> assign(wizard_step: :importing, progress: 0, progress_total: total)
      |> start_async(:import, fn ->
        YoutubeImporter.import_into_group(content_group, selected_videos,
          on_progress: fn idx -> send(parent, {:import_progress, idx}) end
        )
      end)

    {:noreply, socket}
  end

  def handle_event("finish", _params, socket) do
    {:noreply,
     push_navigate(socket, to: ~p"/creators/content_groups/#{socket.assigns.content_group.id}")}
  end

  @impl true
  def handle_async(:lookup, {:ok, {:ok, %{channel_preview: preview, videos: videos}}}, socket) do
    catalog = socket.assigns.catalog

    existing_ids =
      Repo.all(
        from cp in ContentPiece,
          join: g in assoc(cp, :content_group),
          where:
            g.catalog_id == ^catalog.id and not is_nil(cp.youtube_id) and is_nil(cp.archived_at),
          select: cp.youtube_id
      )
      |> MapSet.new()

    {:noreply,
     assign(socket,
       wizard_step: :review,
       channel_preview: preview,
       videos: videos,
       selected_video_ids: MapSet.new(),
       existing_youtube_ids: existing_ids
     )}
  end

  def handle_async(:lookup, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, channel_error: reason)}
  end

  def handle_async(:lookup, {:exit, reason}, socket) do
    {:noreply, assign(socket, channel_error: "Lookup crashed: #{inspect(reason)}")}
  end

  def handle_async(:import, {:ok, {:ok, results}}, socket) do
    {:noreply, assign(socket, wizard_step: :done, import_results: results)}
  end

  def handle_async(:import, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(wizard_step: :review)
     |> put_flash(:error, "Import crashed: #{inspect(reason)}")}
  end

  @impl true
  def handle_info({:import_progress, idx}, socket) do
    {:noreply, assign(socket, progress: idx)}
  end

  # ----- helpers -----

  defp catalog_has_active_tiqit_class?(%{tiqit_classes: classes}) when is_list(classes),
    do: Enum.any?(classes, & &1.active)

  defp catalog_has_active_tiqit_class?(%{id: catalog_id}) when is_integer(catalog_id) do
    Repo.exists?(from tc in TiqitClass, where: tc.catalog_id == ^catalog_id and tc.active == true)
  end

  defp catalog_has_active_tiqit_class?(_), do: false

  @doc false
  def filtered_videos(videos, filter) when is_list(videos) do
    case String.trim(filter || "") do
      "" ->
        videos

      query ->
        q = String.downcase(query)

        Enum.filter(videos, fn v ->
          String.contains?(String.downcase(v.title || ""), q) or
            String.contains?(String.downcase(v.description || ""), q)
        end)
    end
  end

  @wizard_step_order [:channel, :review, :confirm, :importing, :done]

  @doc false
  def step_at_or_past?(current, target) do
    current_idx = Enum.find_index(@wizard_step_order, &(&1 == current)) || 0
    target_idx = Enum.find_index(@wizard_step_order, &(&1 == target)) || 0
    current_idx >= target_idx
  end

  @doc false
  def format_seconds(seconds) when is_integer(seconds) and seconds > 0 do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    cond do
      h > 0 -> "#{h}h #{m}m"
      m > 0 -> "#{m}m #{s}s"
      true -> "#{s}s"
    end
  end

  def format_seconds(_), do: ""
end
