defmodule QlariusWeb.Creators.ContentGroupLive.RssImport do
  @moduledoc """
  Admin wizard that imports a podcast RSS feed as audio `ContentPiece`s.

  Opened from a creator (`:new`, pick a catalog and a new or existing
  group) or from a content group (`:into_group`, target fixed).

  Flow: `:source` → `:review` → `:target` → `:confirm` → `:importing` →
  `:done`. The confirm step shows a dry run of `RssImporter.import_feed/2`.
  """

  use QlariusWeb, :live_view

  import Ecto.Query
  import QlariusWeb.Components.MarketerUI

  alias Qlarius.Repo
  alias Qlarius.Creators.Creator

  alias Qlarius.Tiqit.Arcade.{
    Catalog,
    ContentGroup,
    ContentPiece,
    Creators,
    RssFeed,
    RssImporter
  }

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @steps [:source, :review, :target, :confirm, :importing, :done]

  @impl true
  def mount(params, _session, socket) do
    if admin?(socket) do
      {:ok, socket |> assign_target(params) |> assign_defaults()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be an admin to import feeds.")
       |> redirect(to: ~p"/creators")}
    end
  end

  defp assign_target(socket, %{"content_group_id" => id}) do
    group = Creators.get_content_group!(id)

    assign(socket,
      creator: group.catalog.creator,
      catalogs: [group.catalog],
      catalog_id: group.catalog.id,
      fixed_group: group,
      groups: [group],
      target_mode: "existing",
      group_id: group.id,
      back_path: ~p"/creators/content_groups/#{group.id}",
      back_label: group.title
    )
  end

  defp assign_target(socket, %{"creator_id" => id}) do
    creator = Repo.get!(Creator, id)
    catalogs = Creators.list_catalogs_by_creator(creator.id)
    catalog_id = catalogs |> List.first() |> then(&(&1 && &1.id))

    assign(socket,
      creator: creator,
      catalogs: catalogs,
      catalog_id: catalog_id,
      fixed_group: nil,
      groups: groups_for(catalog_id),
      target_mode: "new",
      group_id: nil,
      back_path: ~p"/creators/#{creator.id}",
      back_label: creator.name
    )
  end

  defp assign_defaults(socket) do
    assign(socket,
      page_title: "Import from RSS",
      step: :source,
      feed_input: "",
      feed_error: nil,
      feed: nil,
      season: nil,
      episode_types: MapSet.new(RssImporter.default_episode_types()),
      selected_guids: MapSet.new(),
      existing_guids: existing_guids(socket.assigns[:group_id]),
      group_title: "",
      auto_sync: false,
      dry_run: nil,
      import_error: nil,
      result: nil
    )
  end

  # ----- events -----

  @impl true
  def handle_event("lookup", %{"feed_url" => url}, socket) do
    {:noreply,
     socket
     |> assign(feed_input: url, feed_error: nil)
     |> start_async(:lookup, fn -> RssImporter.preview(url) end)}
  end

  def handle_event("back", %{"to" => step}, socket) when step in ~w(source review target) do
    {:noreply, assign(socket, step: String.to_existing_atom(step), import_error: nil)}
  end

  def handle_event("filter", params, socket) do
    season =
      case params["season"] do
        "all" -> nil
        "none" -> :none
        value -> parse_int(value)
      end

    types = params |> Map.get("episode_types", []) |> MapSet.new()

    socket = assign(socket, season: season, episode_types: types)
    {:noreply, select_all_visible(socket)}
  end

  def handle_event("toggle_item", %{"guid" => guid}, socket) do
    selected = socket.assigns.selected_guids

    selected =
      if MapSet.member?(selected, guid),
        do: MapSet.delete(selected, guid),
        else: MapSet.put(selected, guid)

    {:noreply, assign(socket, selected_guids: selected)}
  end

  def handle_event("toggle_all", _params, socket) do
    visible = socket.assigns |> visible_items() |> selectable_guids(socket.assigns.existing_guids)

    selected =
      if MapSet.subset?(visible, socket.assigns.selected_guids),
        do: MapSet.difference(socket.assigns.selected_guids, visible),
        else: MapSet.union(socket.assigns.selected_guids, visible)

    {:noreply, assign(socket, selected_guids: selected)}
  end

  def handle_event("continue_to_target", _params, socket) do
    if MapSet.size(selected_in_view(socket.assigns)) == 0 do
      {:noreply, put_flash(socket, :error, "Select at least one episode.")}
    else
      {:noreply, assign(socket, step: :target)}
    end
  end

  def handle_event("target", params, socket) do
    catalog_id = parse_int(params["catalog_id"]) || socket.assigns.catalog_id
    catalog_changed? = catalog_id != socket.assigns.catalog_id
    target_mode = params["target_mode"] || socket.assigns.target_mode

    group_id =
      if catalog_changed? or target_mode == "new", do: nil, else: parse_int(params["group_id"])

    {:noreply,
     assign(socket,
       catalog_id: catalog_id,
       groups: if(catalog_changed?, do: groups_for(catalog_id), else: socket.assigns.groups),
       target_mode: target_mode,
       group_id: group_id,
       existing_guids: existing_guids(group_id),
       group_title: params["group_title"] || socket.assigns.group_title,
       auto_sync: params["auto_sync"] == "true"
     )}
  end

  def handle_event("continue_to_confirm", _params, socket) do
    a = socket.assigns

    cond do
      is_nil(a.catalog_id) ->
        {:noreply, put_flash(socket, :error, "Choose a catalog.")}

      a.target_mode == "existing" and is_nil(a.group_id) ->
        {:noreply, put_flash(socket, :error, "Choose a content group.")}

      a.target_mode == "new" and String.trim(a.group_title) == "" ->
        {:noreply, put_flash(socket, :error, "Give the new group a title.")}

      true ->
        case RssImporter.import_feed(import_params(a, true), feed: a.feed) do
          {:ok, detail} ->
            {:noreply, assign(socket, step: :confirm, dry_run: detail, import_error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, import_error: error_text(reason))}
        end
    end
  end

  def handle_event("start_import", _params, socket) do
    params = import_params(socket.assigns, false)
    feed = socket.assigns.feed

    {:noreply,
     socket
     |> assign(step: :importing)
     |> start_async(:import, fn -> RssImporter.import_feed(params, feed: feed) end)}
  end

  # ----- async -----

  @impl true
  def handle_async(:lookup, {:ok, {:ok, feed}}, socket) do
    default_season = feed.seasons |> List.first() |> then(&(&1 && &1.season))

    {:noreply,
     socket
     |> assign(
       step: :review,
       feed: feed,
       feed_input: feed.feed_url,
       season: default_season,
       group_title: socket.assigns.group_title |> blank_or(feed.channel.title)
     )
     |> select_all_visible()}
  end

  def handle_async(:lookup, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, feed_error: error_text(reason))}
  end

  def handle_async(:lookup, {:exit, reason}, socket) do
    {:noreply, assign(socket, feed_error: "Lookup failed: #{inspect(reason)}")}
  end

  def handle_async(:import, {:ok, {:ok, detail}}, socket) do
    {:noreply, assign(socket, step: :done, result: detail)}
  end

  def handle_async(:import, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, step: :confirm, import_error: error_text(reason))}
  end

  def handle_async(:import, {:exit, reason}, socket) do
    {:noreply, assign(socket, step: :confirm, import_error: "Import crashed: #{inspect(reason)}")}
  end

  # ----- helpers used by the template -----

  def step_at_or_past?(current, target) do
    Enum.find_index(@steps, &(&1 == current)) >= Enum.find_index(@steps, &(&1 == target))
  end

  def visible_items(%{feed: nil}), do: []

  def visible_items(%{feed: feed, season: season, episode_types: types}) do
    feed.items
    |> Enum.filter(fn item ->
      case season do
        nil -> true
        :none -> is_nil(item.season)
        season -> item.season == season
      end
    end)
    |> Enum.filter(&MapSet.member?(types, &1.episode_type))
    |> Enum.sort_by(&RssFeed.sort_key/1)
  end

  def selected_in_view(assigns) do
    visible = assigns |> visible_items() |> Enum.map(& &1.guid) |> MapSet.new()
    MapSet.intersection(visible, assigns.selected_guids)
  end

  def playable?(%{enclosure_url: "https://" <> _}), do: true
  def playable?(_), do: false

  def episode_label(%{episode_type: "trailer"}), do: "Trailer"
  def episode_label(%{episode_type: "bonus"}), do: "Bonus"

  def episode_label(%{season: season, episode_number: n}) when is_integer(n) do
    if season, do: "S#{season} Ep #{n}", else: "Ep #{n}"
  end

  def episode_label(_), do: nil

  def season_label(nil), do: "No season"
  def season_label(season), do: "Season #{season}"

  def format_seconds(seconds) when is_integer(seconds) and seconds > 0 do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    if h > 0, do: "#{h}h #{m}m", else: "#{m}m"
  end

  def format_seconds(_), do: nil

  def catalog_name(catalogs, id) do
    Enum.find_value(catalogs, "", fn catalog -> catalog.id == id && catalog.name end)
  end

  def group_title(groups, id) do
    Enum.find_value(groups, "", fn group -> group.id == id && group.title end)
  end

  @type_fallbacks %{type: "catalog", group_type: "group", piece_type: "episode"}

  def type_word(catalogs, catalog_id, field, count \\ 1, opts \\ []) do
    case Enum.find(catalogs, &(&1.id == catalog_id)) do
      %{^field => type} when not is_nil(type) -> Catalog.type_label(type, count, opts)
      _ -> Catalog.type_label(Map.fetch!(@type_fallbacks, field), count, opts)
    end
  end

  @stepper_steps [
    source: "Feed",
    review: "Episodes",
    target: "Target",
    confirm: "Confirm",
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

  defp notice(assigns) do
    ~H"""
    <div
      role={@tone == "error" && "alert"}
      class={[
        "flex items-start gap-3 rounded-xl border p-4 text-sm",
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
    </div>
    """
  end

  defp notice_icon_class("warning"), do: "size-5 shrink-0 text-warning"
  defp notice_icon_class("error"), do: "size-5 shrink-0 text-error"
  defp notice_icon_class("info"), do: "size-5 shrink-0 text-info"

  # ----- private -----

  defp select_all_visible(socket) do
    guids = socket.assigns |> visible_items() |> selectable_guids(socket.assigns.existing_guids)
    assign(socket, selected_guids: guids)
  end

  defp selectable_guids(items, existing) do
    items
    |> Enum.filter(&playable?/1)
    |> Enum.map(& &1.guid)
    |> Enum.reject(&MapSet.member?(existing, &1))
    |> MapSet.new()
  end

  defp import_params(a, dry_run?) do
    %{
      "feed_url" => a.feed.feed_url,
      "catalog_id" => a.catalog_id,
      "season" => if(is_integer(a.season), do: a.season),
      "episode_types" => MapSet.to_list(a.episode_types),
      "guids" => a |> selected_in_view() |> MapSet.to_list(),
      "content_group_id" => if(a.target_mode == "existing", do: a.group_id),
      "group_title" => a.group_title,
      "auto_sync" => a.auto_sync,
      "dry_run" => dry_run?
    }
  end

  defp groups_for(nil), do: []

  defp groups_for(catalog_id) do
    Repo.all(from g in ContentGroup, where: g.catalog_id == ^catalog_id, order_by: [asc: g.title])
  end

  defp existing_guids(nil), do: MapSet.new()

  defp existing_guids(group_id) do
    Repo.all(
      from p in ContentPiece,
        where: p.content_group_id == ^group_id and not is_nil(p.external_id),
        select: p.external_id
    )
    |> MapSet.new()
  end

  defp admin?(socket) do
    case socket.assigns[:current_scope] do
      %{true_user: %{role: "admin"}} -> true
      _ -> false
    end
  end

  defp error_text({:invalid_pack, errors}) do
    Enum.map_join(errors, "; ", fn
      %{index: index, message: message} -> "Episode #{index + 1}: #{message}"
      %{field: field, message: message} -> "#{field} #{message}"
    end)
  end

  defp error_text(reason) when is_binary(reason), do: reason

  defp error_text(reason) when is_atom(reason),
    do: reason |> to_string() |> String.replace("_", " ")

  defp error_text(reason), do: inspect(reason)

  defp blank_or("", fallback), do: fallback || ""
  defp blank_or(value, _fallback), do: value

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
