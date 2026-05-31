defmodule QlariusWeb.Widgets.Arcade.Paths do
  @moduledoc """
  Internal arqade URLs for mobile (`base_path` `""`), widget (`"/widgets"`),
  and Tiqit public host (`"/tiqit"`).
  """

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
