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
  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentPiece, Creators, TiqitClass, YoutubeImporter}

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
        min_length: "1:00",
        min_seconds: 60,
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
       min_length: "1:00",
       min_seconds: 60,
       selected_video_ids: MapSet.new()
     )}
  end

  def handle_event("filter", params, socket) do
    min_length = Map.get(params, "min_length", socket.assigns.min_length)

    {:noreply,
     assign(socket,
       filter: Map.get(params, "filter", socket.assigns.filter),
       min_length: min_length,
       min_seconds: parse_min_duration(min_length)
     )}
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
      |> filtered_videos(socket.assigns.filter, socket.assigns.min_seconds)
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
  def filtered_videos(videos, filter, min_seconds \\ 0) when is_list(videos) do
    videos
    |> filter_by_text(filter)
    |> filter_by_min_seconds(min_seconds)
  end

  defp filter_by_text(videos, filter) do
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

  defp filter_by_min_seconds(videos, min_seconds)
       when is_integer(min_seconds) and min_seconds > 0 do
    Enum.filter(videos, fn v ->
      length = Map.get(v, :length) || 0
      length <= 0 or length >= min_seconds
    end)
  end

  defp filter_by_min_seconds(videos, _), do: videos

  @doc false
  def parse_min_duration(nil), do: 0
  def parse_min_duration(""), do: 0

  def parse_min_duration(raw) when is_binary(raw) do
    raw = raw |> String.trim() |> String.replace(" ", "")

    cond do
      raw in ["", ":", "0", "0:0", "0:00"] ->
        0

      String.contains?(raw, ":") ->
        case String.split(raw, ":", parts: 2) do
          [min, sec] ->
            minutes = parse_nonneg_int(min) || 0
            seconds = parse_nonneg_int(sec)

            cond do
              is_nil(seconds) and sec == "" ->
                minutes * 60

              is_integer(seconds) and seconds < 60 ->
                minutes * 60 + seconds

              true ->
                0
            end
        end

      true ->
        case parse_nonneg_int(raw) do
          n when is_integer(n) -> n * 60
          _ -> 0
        end
    end
  end

  def parse_min_duration(n) when is_integer(n) and n >= 0, do: n
  def parse_min_duration(_), do: 0

  defp parse_nonneg_int(""), do: 0

  defp parse_nonneg_int(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  @doc false
  def format_min_sec(seconds) when is_integer(seconds) and seconds > 0 do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}:#{String.pad_leading(Integer.to_string(s), 2, "0")}"
  end

  def format_min_sec(_), do: "0:00"

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

  @stepper_steps [
    channel: "Source",
    review: "Review",
    confirm: "Confirm",
    importing: "Import",
    done: "Done"
  ]

  defp stepper_steps(current) do
    reached = Enum.filter(@stepper_steps, fn {step, _} -> step_at_or_past?(current, step) end)
    {active, _} = List.last(reached)

    Enum.map(@stepper_steps, fn {step, label} ->
      state =
        cond do
          not step_at_or_past?(current, step) -> :upcoming
          step == active and current != :done -> :current
          true -> :complete
        end

      %{label: label, state: state}
    end)
  end

  attr :steps, :list, required: true

  defp wizard_stepper(assigns) do
    ~H"""
    <ol aria-label="Import steps" class="mb-6 flex flex-wrap items-center gap-x-3 gap-y-3">
      <li
        :for={{step, idx} <- Enum.with_index(@steps, 1)}
        aria-current={step.state == :current && "step"}
        class="flex items-center gap-2.5"
      >
        <span class={[
          "flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold",
          step.state == :complete && "bg-primary/15 text-primary",
          step.state == :current && "bg-primary text-primary-content ring-4 ring-primary/20",
          step.state == :upcoming && "border border-base-300 text-base-content/50"
        ]}>
          <.icon :if={step.state == :complete} name="hero-check" class="size-4" />
          <span :if={step.state != :complete}>{idx}</span>
        </span>
        <span class={[
          "text-sm",
          step.state == :current && "font-medium text-base-content",
          step.state == :complete && "text-base-content/70",
          step.state == :upcoming && "text-base-content/50"
        ]}>
          {step.label}
        </span>
        <span
          :if={idx < length(@steps)}
          class="ml-0.5 h-px w-6 bg-base-300 sm:w-10"
          aria-hidden="true"
        >
        </span>
      </li>
    </ol>
    """
  end

  attr :tone, :string, default: "warning", values: ~w(warning error info)
  attr :icon, :string, default: "hero-exclamation-triangle"
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :action

  defp notice(assigns) do
    ~H"""
    <div
      role={@tone == "error" && "alert"}
      class={[
        "flex flex-wrap items-start gap-3 rounded-xl border p-4 text-sm",
        @tone == "warning" && "border-warning/30 bg-warning/10",
        @tone == "error" && "border-error/30 bg-error/10",
        @tone == "info" && "border-info/30 bg-info/10",
        @class
      ]}
    >
      <.icon name={@icon} class={notice_icon_class(@tone)} />
      <div class="min-w-0 flex-1">
        <p :if={@title} class="font-medium">{@title}</p>
        <div class={[@title && "mt-0.5", "text-base-content/70"]}>{render_slot(@inner_block)}</div>
      </div>
      <div :if={@action != []} class="shrink-0">{render_slot(@action)}</div>
    </div>
    """
  end

  defp notice_icon_class("warning"), do: "size-5 shrink-0 text-warning"
  defp notice_icon_class("error"), do: "size-5 shrink-0 text-error"
  defp notice_icon_class("info"), do: "size-5 shrink-0 text-info"
end
