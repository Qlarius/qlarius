defmodule Qlarius.AdminApi.Embeds do
  @moduledoc """
  Relative widget paths for a creator. The host that serves the page
  supplies the origin; these paths do not include a digested filename.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}

  @sponster_script "/sponster-tipjar-widget-ext-script.js"
  @arqade_script "/tiqit-arqade-widget-script.js"

  def for_creator(creator) do
    creator = Repo.preload(creator, :recipient)
    catalogs = Repo.all(from c in Catalog, where: c.creator_id == ^creator.id, order_by: [asc: c.id])
    catalog_ids = Enum.map(catalogs, & &1.id)

    groups =
      Repo.all(
        from g in ContentGroup,
          where: g.catalog_id in ^catalog_ids,
          order_by: [asc: g.id]
      )

    group_ids = Enum.map(groups, & &1.id)

    pieces =
      Repo.all(
        from p in ContentPiece,
          where: p.content_group_id in ^group_ids and is_nil(p.archived_at),
          order_by: [asc: p.display_order, asc: p.id]
      )

    recipient = creator.recipient
    split_code = recipient && recipient.split_code

    %{
      creator_id: creator.id,
      split_code: split_code,
      referral_code: recipient && recipient.referral_code,
      scripts: %{
        sponster: @sponster_script,
        arqade: @arqade_script
      },
      widgets: %{
        sponster_bar: split_code && "/widgets/ads_ext/#{split_code}",
        insta_tip: split_code && "/widgets/insta_tip?split_code=#{split_code}",
        creator: "/widgets/arqade/creator/#{creator.id}",
        catalogs:
          Enum.map(catalogs, fn catalog ->
            %{
              id: catalog.id,
              path: "/widgets/arqade/catalog/#{catalog.id}",
              tiqit_pass: "/widgets/tiqit_pass/#{catalog.id}"
            }
          end),
        groups: Enum.map(groups, &%{id: &1.id, catalog_id: &1.catalog_id, path: "/widgets/arqade/group/#{&1.id}"}),
        pieces:
          Enum.map(pieces, fn piece ->
            %{id: piece.id, content_group_id: piece.content_group_id, path: "/widgets/arqade/#{piece.id}"}
          end)
      }
    }
  end
end