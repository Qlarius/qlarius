defmodule Qlarius.Tiqit.ContentAudiencesTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.Accounts
  alias Qlarius.Accounts.{Marketers, Scope}
  alias Qlarius.Creators
  alias Qlarius.Sponster.Campaigns.{Target, TargetBand, TargetPopulation}
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, Tiqit}
  alias Qlarius.Tiqit.ContentAudienceTarget
  alias Qlarius.Tiqit.ContentAudiences

  defp user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        alias: "user-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    {:ok, %{user: user}} = Accounts.register_new_user(attrs)
    user
  end

  defp catalog!(creator) do
    %Catalog{creator_id: creator.id}
    |> Catalog.changeset(%{
      name: "Cat #{System.unique_integer([:positive])}",
      url: "https://example.com/#{System.unique_integer([:positive])}",
      type: :catalog,
      group_type: :show,
      piece_type: :episode
    })
    |> Repo.insert!()
  end

  defp group!(catalog, title \\ "Show") do
    %ContentGroup{catalog_id: catalog.id}
    |> ContentGroup.changeset(%{title: title})
    |> Repo.insert!()
  end

  defp piece!(group, title, date \\ ~D[2025-06-01]) do
    %ContentPiece{content_group_id: group.id}
    |> ContentPiece.changeset(%{title: title, date_published: date})
    |> Repo.insert!()
  end

  defp populate_band!(band, me_file, attrs \\ %{}) do
    %TargetPopulation{}
    |> TargetPopulation.changeset(
      Map.merge(
        %{
          target_band_id: band.id,
          me_file_id: me_file.id,
          matching_tags_snapshot: %{"tags" => []}
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp mark_populated!(target) do
    target
    |> Target.changeset(%{population_status: "populated"})
    |> Repo.update!()
  end

  setup do
    user = user_fixture()
    creator = creator_fixture()
    {:ok, _} = Creators.create_creator_membership(creator.id, user.id, :owner)

    catalog = catalog!(creator)
    group = group!(catalog)
    piece = piece!(group, "Episode")

    parent = parent_trait_fixture("Interests")
    music = trait_fixture(parent, "Music", 1)
    travel = trait_fixture(parent, "Travel", 2)

    %{
      user: user,
      scope: Scope.for_user(user),
      creator: creator,
      catalog: catalog,
      group: group,
      piece: piece,
      parent: parent,
      music: music,
      travel: travel
    }
  end

  describe "set_attachment/4" do
    test "attaches a creator-owned audience at each level", ctx do
      {:ok, target} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

      assert {:ok, a} = ContentAudiences.set_attachment(ctx.scope, target, ctx.catalog, :boost)
      assert a.catalog_id == ctx.catalog.id
      assert a.mode == :boost

      assert {:ok, _} = ContentAudiences.set_attachment(ctx.scope, target, ctx.group, :gate)
      assert {:ok, _} = ContentAudiences.set_attachment(ctx.scope, target, ctx.piece, :boost)
      assert {:ok, _} = ContentAudiences.set_attachment(ctx.scope, target, ctx.creator, :boost)
    end

    test "replaces an existing attachment at the same slot", ctx do
      {:ok, first} = ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "A"})
      {:ok, second} = ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "B"})

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, first, ctx.catalog, :boost)
      {:ok, replaced} = ContentAudiences.set_attachment(ctx.scope, second, ctx.catalog, :boost)

      assert replaced.target_id == second.id

      assert Repo.aggregate(
               from(a in ContentAudienceTarget, where: a.catalog_id == ^ctx.catalog.id),
               :count
             ) == 1
    end

    test "rejects a marketer-owned target", ctx do
      marketer = marketer_fixture()
      {:ok, _} = Marketers.create_marketer_membership(marketer.id, ctx.user.id, :owner)

      {:ok, target} =
        Qlarius.Sponster.Campaigns.Targets.create_target(%{
          title: "Ads",
          marketer_id: marketer.id
        })

      assert {:error, :wrong_owner} =
               ContentAudiences.set_attachment(ctx.scope, target, ctx.catalog, :boost)
    end

    test "rejects a user who is not a member of the creator", ctx do
      stranger = user_fixture()

      {:ok, target} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

      assert {:error, :unauthorized} =
               ContentAudiences.set_attachment(
                 Scope.for_user(stranger),
                 target,
                 ctx.catalog,
                 :boost
               )
    end
  end

  describe "resolve/3 inheritance" do
    setup ctx do
      {:ok, catalog_aud} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Catalog fans"})

      {:ok, piece_aud} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Guest fans"})

      {:ok, gate_aud} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "21+"})

      me_file = me_file_fixture()

      %{
        catalog_aud: mark_populated!(catalog_aud),
        piece_aud: mark_populated!(piece_aud),
        gate_aud: mark_populated!(gate_aud),
        me_file: me_file
      }
    end

    defp band!(target) do
      %TargetBand{}
      |> TargetBand.changeset(%{
        target_id: target.id,
        is_bullseye: "1",
        tier: 0,
        population_count: 3_000
      })
      |> Repo.insert!()
    end

    test "piece boost overrides catalog; catalog gate still applies", ctx do
      catalog_band = band!(ctx.catalog_aud)
      piece_band = band!(ctx.piece_aud)
      gate_band = band!(ctx.gate_aud)

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.catalog_aud, ctx.catalog, :boost)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.piece_aud, ctx.piece, :boost)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.gate_aud, ctx.catalog, :gate)

      populate_band!(catalog_band, ctx.me_file)
      populate_band!(piece_band, ctx.me_file)
      populate_band!(gate_band, ctx.me_file)

      matches = ContentAudiences.matches_for_me_file(ctx.me_file.id)
      gates = ContentAudiences.gate_attachments()
      ancestry = ContentAudiences.ancestry_for(ctx.piece)

      result = ContentAudiences.resolve(ancestry, matches, gates)

      assert result.visible?
      assert result.boost_source == :piece
      assert result.boost_match.target_id == ctx.piece_aud.id
      assert result.blocking_gates == []
      assert Enum.map(result.applied_gates, & &1.target_id) == [ctx.gate_aud.id]
    end

    test "a catalog fallback applies when the piece has no boost of its own", ctx do
      catalog_band = band!(ctx.catalog_aud)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.catalog_aud, ctx.catalog, :boost)
      populate_band!(catalog_band, ctx.me_file)

      result =
        ContentAudiences.resolve(
          ContentAudiences.ancestry_for(ctx.piece),
          ContentAudiences.matches_for_me_file(ctx.me_file.id),
          ContentAudiences.gate_attachments()
        )

      assert result.boost_source == :catalog
      assert result.boost_match.target_id == ctx.catalog_aud.id
    end

    test "an unmatched populated gate hides the piece", ctx do
      gate_band = band!(ctx.gate_aud)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.gate_aud, ctx.catalog, :gate)
      # Population exists for the gate, but not for this me_file.
      other = me_file_fixture()
      populate_band!(gate_band, other)

      result =
        ContentAudiences.resolve(
          ContentAudiences.ancestry_for(ctx.piece),
          ContentAudiences.matches_for_me_file(ctx.me_file.id),
          ContentAudiences.gate_attachments()
        )

      refute result.visible?
      assert result.blocking_gates == [ctx.gate_aud.id]
    end

    test "an unpopulated gate is inert", ctx do
      _band = band!(ctx.gate_aud)

      ctx.gate_aud
      |> Target.changeset(%{population_status: "populating"})
      |> Repo.update!()

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.gate_aud, ctx.catalog, :gate)

      result =
        ContentAudiences.resolve(
          ContentAudiences.ancestry_for(ctx.piece),
          ContentAudiences.empty_matches(),
          ContentAudiences.gate_attachments()
        )

      assert result.visible?
      assert result.blocking_gates == []
    end

    test "anonymous visitors satisfy no gates and get no boosts", ctx do
      catalog_band = band!(ctx.catalog_aud)
      gate_band = band!(ctx.gate_aud)

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.catalog_aud, ctx.catalog, :boost)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.gate_aud, ctx.catalog, :gate)
      populate_band!(catalog_band, ctx.me_file)
      populate_band!(gate_band, ctx.me_file)

      result =
        ContentAudiences.resolve(
          ContentAudiences.ancestry_for(ctx.piece),
          ContentAudiences.empty_matches(),
          ContentAudiences.gate_attachments()
        )

      refute result.visible?
      assert result.boost_source == nil
    end

    test "ranking prefers a narrower audience, then more conditions, then a closer level", ctx do
      wide =
        band!(ctx.catalog_aud)
        |> TargetBand.changeset(%{population_count: 80_000, tier: 0})
        |> Repo.update!()

      narrow =
        band!(ctx.piece_aud)
        |> TargetBand.changeset(%{population_count: 2_000, tier: 0})
        |> Repo.update!()

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.catalog_aud, ctx.catalog, :boost)
      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, ctx.piece_aud, ctx.piece, :boost)
      populate_band!(wide, ctx.me_file)
      populate_band!(narrow, ctx.me_file)

      piece_result =
        ContentAudiences.resolve(
          ContentAudiences.ancestry_for(ctx.piece),
          ContentAudiences.matches_for_me_file(ctx.me_file.id),
          ContentAudiences.gate_attachments()
        )

      # Piece-level 2k-person audience is bucket 1; catalog 80k is bucket 2.
      # The piece wins on selectivity even before level is considered.
      assert piece_result.boost_source == :piece
      {bucket, _conds, level_rank, _recency, _id} = piece_result.rank
      assert bucket == 1
      assert level_rank == 0
    end
  end

  describe "effective_audience/1" do
    test "reports inheriting vs set-here", ctx do
      {:ok, target} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, target, ctx.catalog, :boost)

      catalog_slot = ContentAudiences.effective_audience(ctx.catalog)
      assert catalog_slot.boost.state == :set_here
      assert catalog_slot.boost.attachment.target_id == target.id

      piece_slot = ContentAudiences.effective_audience(ctx.piece)
      assert piece_slot.boost.state == :inheriting
      assert piece_slot.boost.inherited.level == :catalog
      assert piece_slot.boost.inherited.target.id == target.id
    end
  end

  describe "copy_within_org/3 and copy-on-write" do
    test "refine shares trait groups; editing a shared group forks it", ctx do
      {:ok, source} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Show fans"})

      {:ok, _} =
        ContentAudiences.set_question_answers(ctx.scope, source, ctx.parent.id, [ctx.music.id])

      source = ContentAudiences.get_audience!(ctx.creator.id, source.id)
      {:ok, refined} = ContentAudiences.copy_within_org(ctx.scope, source, title: "Guest niche")

      source_group_ids =
        source.target_bands |> Enum.flat_map(& &1.trait_groups) |> Enum.map(& &1.id)

      refined_group_ids =
        refined.target_bands |> Enum.flat_map(& &1.trait_groups) |> Enum.map(& &1.id)

      assert source_group_ids == refined_group_ids
      refute refined.id == source.id

      {:ok, _} =
        ContentAudiences.set_question_answers(ctx.scope, refined, ctx.parent.id, [
          ctx.music.id,
          ctx.travel.id
        ])

      source_after = ContentAudiences.get_audience!(ctx.creator.id, source.id)
      refined_after = ContentAudiences.get_audience!(ctx.creator.id, refined.id)

      source_group = hd(hd(source_after.target_bands).trait_groups)
      refined_group = hd(hd(refined_after.target_bands).trait_groups)

      refute source_group.id == refined_group.id
      assert Enum.map(source_group.traits, & &1.id) == [ctx.music.id]

      assert Enum.map(refined_group.traits, & &1.id) |> Enum.sort() ==
               Enum.sort([ctx.music.id, ctx.travel.id])
    end
  end

  describe "piece_visible?/2" do
    test "hides a gated piece from a non-matching user", ctx do
      {:ok, gate} = ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "21+"})
      gate = mark_populated!(gate)

      band =
        %TargetBand{}
        |> TargetBand.changeset(%{target_id: gate.id, is_bullseye: "1", tier: 0})
        |> Repo.insert!()

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, gate, ctx.catalog, :gate)
      populate_band!(band, me_file_fixture())

      refute ContentAudiences.piece_visible?(ctx.scope, ctx.piece)
    end

    test "a valid tiqit bypasses a populated gate", ctx do
      {:ok, gate} = ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "21+"})
      gate = mark_populated!(gate)

      band =
        %TargetBand{}
        |> TargetBand.changeset(%{target_id: gate.id, is_bullseye: "1", tier: 0})
        |> Repo.insert!()

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, gate, ctx.catalog, :gate)
      populate_band!(band, me_file_fixture())

      refute ContentAudiences.piece_visible?(ctx.scope, ctx.piece)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %Tiqit{me_file_id: ctx.scope.user.me_file.id}
      |> Tiqit.changeset(%{
        purchased_at: now,
        expires_at: DateTime.add(now, 3, :hour),
        content_piece_id: ctx.piece.id
      })
      |> Repo.insert!()

      assert ContentAudiences.piece_visible?(ctx.scope, ctx.piece)
    end
  end

  describe "why_you/2" do
    test "names the creator and reads parsed tuples, not inspect/1", ctx do
      {:ok, target} =
        ContentAudiences.create_audience(ctx.scope, ctx.creator.id, %{title: "Fans"})

      target = mark_populated!(target)

      band =
        %TargetBand{}
        |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1", tier: 0})
        |> Repo.insert!()

      {:ok, _} = ContentAudiences.set_attachment(ctx.scope, target, ctx.piece, :boost)

      snapshot = %{
        "tags" => [[ctx.parent.id, "Interests", 1, [[ctx.music.id, "Music", 1]]]]
      }

      populate_band!(band, ctx.scope.user.me_file, %{matching_tags_snapshot: snapshot})

      why = ContentAudiences.why_you(ctx.scope, ctx.piece)

      assert why.label == "Because you're into Interests"
      assert why.source_copy == "#{ctx.creator.name} set this audience for this episode"
      assert [{_, "Interests", _, children}] = why.parent_traits
      assert Enum.any?(children, fn tuple -> elem(tuple, 1) == "Music" end)
      refute why.label =~ "parent_trait"
    end
  end
end
