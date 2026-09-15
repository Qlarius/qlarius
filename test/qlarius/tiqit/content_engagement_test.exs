defmodule Qlarius.Tiqit.ContentEngagementTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.TargetBand
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, Tiqit, TiqitClass}
  alias Qlarius.Tiqit.{ContentEngagement, ContentEngagementEvent, ContentImpressionDaily}

  defp user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, %{user: user}} = Accounts.register_new_user(attrs)
    user
  end

  setup do
    user = user_fixture()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Cat #{System.unique_integer([:positive])}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Show"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{title: "Episode", date_published: ~D[2025-06-01]})
      |> Repo.insert!()

    catalog = Repo.preload(catalog, :creator)
    group = %{group | catalog: catalog}
    piece = %{piece | content_group: group}

    {:ok, target} =
      Qlarius.Tiqit.ContentAudiences.create_audience(Scope.for_user(user), creator.id, %{
        title: "Fans"
      })

    band =
      %TargetBand{}
      |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1", tier: 0, population_count: 12})
      |> Repo.insert!()

    user = Repo.preload(user, :me_file)

    %{
      user: user,
      scope: Scope.for_user(user),
      creator: creator,
      catalog: catalog,
      group: group,
      piece: piece,
      target: target,
      band: band
    }
  end

  test "record/1 writes matching FK and _ss pairs from the same struct", ctx do
    {:ok, event} =
      ContentEngagement.record(%{
        type: :click,
        surface: :picked_for_you,
        piece: ctx.piece,
        group: ctx.group,
        catalog: ctx.catalog,
        creator: ctx.creator,
        band: ctx.band,
        target: ctx.target,
        me_file_id: ctx.user.me_file.id,
        snapshot: %{"tags" => [%{"trait_name" => "Music"}]},
        tier: 0,
        population_count: 12,
        boost_level: "piece"
      })

    assert event.content_piece_id == ctx.piece.id
    assert event.content_piece_id_ss == ctx.piece.id
    assert event.content_piece_title_ss == "Episode"
    assert event.target_band_id == ctx.band.id
    assert event.target_band_id_ss == ctx.band.id
    assert event.target_id == ctx.target.id
    assert event.target_id_ss == ctx.target.id
    assert event.creator_id == ctx.creator.id
    assert event.creator_id_ss == ctx.creator.id
    assert event.creator_name_ss == ctx.creator.name
    assert event.matching_tags_snapshot["tags"]
  end

  test "an event survives deleting its content with _ss intact", ctx do
    {:ok, event} =
      ContentEngagement.record(%{
        type: :click,
        surface: :direct,
        piece: ctx.piece,
        group: ctx.group,
        catalog: ctx.catalog,
        creator: ctx.creator
      })

    {:ok, _} = Repo.delete(ctx.piece)

    reloaded = Repo.get!(ContentEngagementEvent, event.id)
    assert is_nil(reloaded.content_piece_id)
    assert reloaded.content_piece_id_ss == ctx.piece.id
    assert reloaded.content_piece_title_ss == "Episode"
  end

  test "organic and deleted-band events are distinguishable", ctx do
    {:ok, organic} =
      ContentEngagement.record(%{
        type: :click,
        surface: :more_from_creators,
        piece: ctx.piece,
        creator: ctx.creator
      })

    {:ok, boosted} =
      ContentEngagement.record(%{
        type: :click,
        surface: :picked_for_you,
        piece: ctx.piece,
        creator: ctx.creator,
        band: ctx.band,
        target: ctx.target
      })

    {:ok, _} = Repo.delete(ctx.band)

    organic = Repo.get!(ContentEngagementEvent, organic.id)
    boosted = Repo.get!(ContentEngagementEvent, boosted.id)

    assert is_nil(organic.target_band_id)
    assert is_nil(organic.target_band_id_ss)

    assert is_nil(boosted.target_band_id)
    assert boosted.target_band_id_ss == ctx.band.id
  end

  test "anonymize_for_me_file/1 clears the trait snapshot and session", ctx do
    {:ok, event} =
      ContentEngagement.record(%{
        type: :click,
        surface: :direct,
        piece: ctx.piece,
        creator: ctx.creator,
        me_file_id: ctx.user.me_file.id,
        session_id: "sess-1",
        snapshot: %{"tags" => [%{"trait_name" => "Music"}]}
      })

    {1, _} = Accounts.anonymize_user_personal_data(ctx.user)

    reloaded = Repo.get!(ContentEngagementEvent, event.id)
    assert is_nil(reloaded.me_file_id)
    assert is_nil(reloaded.matching_tags_snapshot)
    assert is_nil(reloaded.session_id)
    assert reloaded.content_piece_title_ss == "Episode"
    assert reloaded.surface == :direct
  end

  test "record_impression/3 upserts the daily counter including organic rows", ctx do
    assert :ok = ContentEngagement.record_impression(ctx.piece, :picked_for_you)
    assert :ok = ContentEngagement.record_impression(ctx.piece, :picked_for_you)
    assert :ok = ContentEngagement.record_impression(ctx.piece, :picked_for_you, ctx.band)

    organic =
      Repo.one!(
        from d in ContentImpressionDaily,
          where:
            d.content_piece_id == ^ctx.piece.id and d.surface == "picked_for_you" and
              is_nil(d.target_band_id)
      )

    boosted =
      Repo.get_by!(ContentImpressionDaily,
        content_piece_id: ctx.piece.id,
        surface: "picked_for_you",
        target_band_id: ctx.band.id
      )

    assert organic.impressions == 2
    assert boosted.impressions == 1
  end

  test "a click bumps the daily click counter", ctx do
    {:ok, _} =
      ContentEngagement.record(%{
        type: :click,
        surface: :browse,
        piece: ctx.piece,
        creator: ctx.creator
      })

    row =
      Repo.get_by!(ContentImpressionDaily,
        content_piece_id: ctx.piece.id,
        surface: "browse"
      )

    assert row.clicks == 1
    assert row.impressions == 0
  end

  test "purchase copies last-touch click attribution", ctx do
    {:ok, click} =
      ContentEngagement.record(%{
        type: :click,
        surface: :picked_for_you,
        piece: ctx.piece,
        group: ctx.group,
        catalog: ctx.catalog,
        creator: ctx.creator,
        band: ctx.band,
        target: ctx.target,
        me_file_id: ctx.user.me_file.id,
        snapshot: %{"tags" => [%{"trait_name" => "Music"}]},
        tier: 0,
        population_count: 12,
        boost_level: "piece"
      })

    class =
      %TiqitClass{content_piece_id: ctx.piece.id}
      |> TiqitClass.changeset(%{duration_hours: 3, price: Decimal.new("0.10")})
      |> Repo.insert!()
      |> Repo.preload(content_piece: [content_group: [catalog: :creator]])

    tiqit =
      %Tiqit{
        me_file_id: ctx.user.me_file.id,
        tiqit_class_id: class.id
      }
      |> Tiqit.changeset(%{
        purchased_at: DateTime.utc_now() |> DateTime.truncate(:second),
        price: Decimal.new("0.10"),
        duration_hours: 3,
        content_piece_id: ctx.piece.id
      })
      |> Repo.insert!()

    {:ok, purchase} = ContentEngagement.record_purchase(ctx.scope, tiqit, class)

    assert purchase.type == :tiqit_purchase
    assert purchase.surface == :picked_for_you
    assert purchase.target_band_id == ctx.band.id
    assert purchase.target_band_id_ss == ctx.band.id
    assert purchase.matching_tags_snapshot == click.matching_tags_snapshot
    assert purchase.tiqit_id == tiqit.id
    assert purchase.tiqit_id_ss == tiqit.id
  end

  test "recommended_vs_organic/1 splits on target_band_id_ss", ctx do
    {:ok, _} =
      ContentEngagement.record(%{
        type: :click,
        surface: :more_from_creators,
        piece: ctx.piece,
        creator: ctx.creator
      })

    {:ok, _} =
      ContentEngagement.record(%{
        type: :click,
        surface: :picked_for_you,
        piece: ctx.piece,
        creator: ctx.creator,
        band: ctx.band
      })

    split = ContentEngagement.recommended_vs_organic(ctx.creator.id)
    assert split.recommended == 1
    assert split.organic == 1
  end

  test "per_audience_conversion/1 reports clicks and purchases for a target", ctx do
    {:ok, _} =
      ContentEngagement.record(%{
        type: :click,
        surface: :picked_for_you,
        piece: ctx.piece,
        creator: ctx.creator,
        target: ctx.target,
        band: ctx.band
      })

    {:ok, _} =
      ContentEngagement.record(%{
        type: :tiqit_purchase,
        surface: :picked_for_you,
        piece: ctx.piece,
        creator: ctx.creator,
        target: ctx.target,
        band: ctx.band
      })

    [row] = ContentEngagement.per_audience_conversion(ctx.creator.id)
    assert row.target_id == ctx.target.id
    assert row.clicks == 1
    assert row.purchases == 1
    assert Decimal.eq?(row.conversion, Decimal.new(1))
  end
end
