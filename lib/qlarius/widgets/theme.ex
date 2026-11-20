defmodule Qlarius.Widgets.Theme do
  @moduledoc """
  How an embeddable widget chooses light, dark, or the viewer's device.

  An explicit `force_theme` of light or dark wins. Otherwise an arqade uses
  its content group's override, then the creator default. Ad strip and tip
  jar use the creator fields for that widget. Anything else is `"system"`.

  `"system"` is not a `data-theme` value. `pin/1` drops it so the page follows
  the viewer. `concrete/1` is the light fallback for a caller that must paint
  one color and cannot read the device.
  """

  import Ecto.Query

  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece

  @themes ~w(light dark system)
  @pinned ~w(light dark)

  def themes, do: @themes

  def options do
    [{"Light", "light"}, {"Dark", "dark"}, {"System", "system"}]
  end

  def label("light"), do: "Light"
  def label("dark"), do: "Dark"
  def label(_), do: "System"

  def explicit(value) when value in @pinned, do: value
  def explicit(_), do: nil

  def normalize(value) when value in @themes, do: value
  def normalize(_), do: "system"

  def pin(value) when value in @pinned, do: value
  def pin(_), do: nil

  def concrete(value) when value in @pinned, do: value
  def concrete(_), do: "light"

  def widget_attr("/widgets", theme), do: pin(theme)
  def widget_attr(_base_path, _theme), do: nil

  def resolve(explicit, stored) do
    explicit(explicit) || normalize(stored)
  end

  def resolve_arqade(explicit, group_theme, creator_theme) do
    explicit(explicit) || normalize_group(group_theme) || normalize(creator_theme)
  end

  def for_group(group_id, explicit) do
    case themes_for_group(group_id) do
      nil -> resolve(explicit, nil)
      {group_theme, creator_theme} -> resolve_arqade(explicit, group_theme, creator_theme)
    end
  end

  def for_piece(piece_id, explicit) do
    case id(piece_id) do
      nil ->
        resolve(explicit, nil)

      piece_id ->
        group_id =
          Repo.one(from p in ContentPiece, where: p.id == ^piece_id, select: p.content_group_id)

        for_group(group_id, explicit)
    end
  end

  def for_catalog(catalog_id, explicit) do
    stored =
      case id(catalog_id) do
        nil ->
          nil

        catalog_id ->
          Repo.one(
            from c in Catalog,
              join: creator in assoc(c, :creator),
              where: c.id == ^catalog_id,
              select: creator.arqade_theme
          )
      end

    resolve(explicit, stored)
  end

  def for_recipient(recipient, field, explicit)
      when field in [:ad_strip_theme, :tip_jar_theme] do
    stored =
      case recipient do
        %Recipient{creator_id: creator_id} when is_integer(creator_id) ->
          Repo.one(from c in Creator, where: c.id == ^creator_id, select: field(c, ^field))

        # Legacy/partial data: a recipient may not have creator_id populated,
        # but the creator can still reference its primary recipient via
        # creators.recipient_id.
        %Recipient{id: recipient_id} when is_integer(recipient_id) ->
          Repo.one(
            from c in Creator,
              where: c.recipient_id == ^recipient_id,
              order_by: [asc: c.id],
              limit: 1,
              select: field(c, ^field)
          )

        _ ->
          nil
      end

    resolve(explicit, stored)
  end

  defp normalize_group(value) when value in @themes, do: value
  defp normalize_group(_), do: nil

  defp themes_for_group(group_id) do
    case id(group_id) do
      nil ->
        nil

      group_id ->
        Repo.one(
          from g in ContentGroup,
            join: catalog in assoc(g, :catalog),
            join: creator in assoc(catalog, :creator),
            where: g.id == ^group_id,
            select: {g.arqade_theme, creator.arqade_theme}
        )
    end
  end

  defp id(id) when is_integer(id), do: id

  defp id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp id(_), do: nil
end
