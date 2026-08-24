defmodule QlariusWeb.Widgets.Arcade.Paths do
  @moduledoc """
  Internal arqade URLs for mobile (`base_path` `""`), widget (`"/widgets"`),
  and Tiqit public host (`"/tiqit"`).
  """

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup

  @doc "Discovery root — `/arqade`, `/widgets/arqade`, or `/tiqit/arqade`."
  def discover(""), do: "/arqade"
  def discover("/widgets"), do: "/widgets/arqade"
  def discover("/tiqit"), do: "/tiqit/arqade"
  def discover(base_path), do: "#{base_path}/arqade"

  @doc "Creator landing — `/arqade/creator/:id` or `/tiqit/arqade/creator/:id`."
  def creator(base_path, creator_id) do
    "#{discover(base_path)}/creator/#{creator_id}"
  end

  @doc "Catalog page."
  def catalog(base_path, catalog_id) do
    "#{discover(base_path)}/catalog/#{catalog_id}"
  end

  @doc """
  Discover/creator entry for a catalog. When the catalog has exactly one
  navigable group, skip the catalog page and go to that group.
  """
  def catalog_destination(base_path, %Catalog{} = catalog) do
    case only_navigable_group(catalog) do
      %{id: group_id} -> group(base_path, group_id)
      _ -> catalog(base_path, catalog.id)
    end
  end

  @doc """
  Crumbs above a group: creator, plus catalog only when that catalog has
  more than one navigable group.
  """
  def group_crumbs(base_path, group) do
    catalog = group.catalog
    creator = catalog.creator
    crumbs = [{creator.name, creator(base_path, creator.id)}]

    if skip_catalog_crumb?(catalog) do
      crumbs
    else
      crumbs ++ [{catalog.name, catalog(base_path, catalog.id)}]
    end
  end

  @doc "Crumbs above a piece: `group_crumbs/2` plus the group itself."
  def piece_crumbs(base_path, group) do
    group_crumbs(base_path, group) ++ [{group.title, group(base_path, group.id)}]
  end

  def skip_catalog_crumb?(%Catalog{} = catalog) do
    match?([_], navigable_groups(catalog))
  end

  def only_navigable_group(%Catalog{} = catalog) do
    case navigable_groups(catalog) do
      [group] -> group
      _ -> nil
    end
  end

  defp navigable_groups(%Catalog{} = catalog) do
    groups =
      if Ecto.assoc_loaded?(catalog.content_groups),
        do: catalog.content_groups,
        else: []

    groups =
      if Enum.any?(groups, &Ecto.assoc_loaded?(&1.content_pieces)) do
        Enum.filter(groups, fn group ->
          Ecto.assoc_loaded?(group.content_pieces) and
            ContentGroup.has_active_content_pieces?(group.content_pieces)
        end)
      else
        groups
      end

    Enum.sort_by(groups, & &1.inserted_at, :desc)
  end

  @doc "Content group — Tiqit uses `/tiqit/arqade/:id`; mobile uses `/arqade/group/:id`."
  def group("/tiqit", group_id), do: "/tiqit/arqade/#{group_id}"
  def group(base_path, group_id), do: "#{discover(base_path)}/group/#{group_id}"

  @doc "Single piece — Tiqit uses `/tiqit/arqade/piece/:id`; mobile uses `/arqade/:id`."
  def piece("/tiqit", piece_id), do: "/tiqit/arqade/piece/#{piece_id}"
  def piece(base_path, piece_id), do: "#{discover(base_path)}/#{piece_id}"

  @doc """
  Resolves `base_path` from the request URI when not already set by `on_mount`.
  """
  def resolve_base_path(uri, existing \\ nil)

  def resolve_base_path(_uri, existing) when is_binary(existing) and existing != "", do: existing

  def resolve_base_path(uri, _existing) when is_binary(uri) do
    cond do
      String.contains?(uri, "/widgets/") -> "/widgets"
      String.contains?(uri, "/tiqit/") -> "/tiqit"
      true -> ""
    end
  end

  def resolve_base_path(_, _), do: ""
end
