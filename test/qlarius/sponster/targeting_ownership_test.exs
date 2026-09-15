defmodule Qlarius.Sponster.TargetingOwnershipTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Creators
  alias Qlarius.Sponster.Campaigns

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    Target,
    TargetBand,
    TargetPopulation,
    Targets,
    TraitGroup
  }

  alias Qlarius.YouData.MeFiles.MeFile

  defp marketer! do
    %Marketer{}
    |> Marketer.changeset(%{business_name: "Marketer #{System.unique_integer([:positive])}"})
    |> Repo.insert!()
  end

  defp creator! do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Creator #{System.unique_integer([:positive])}"})

    creator
  end

  defp target!(attrs) do
    %Target{}
    |> Target.changeset(Map.merge(%{title: "T #{System.unique_integer([:positive])}"}, attrs))
    |> Repo.insert!()
  end

  describe "exactly-one-owner rule" do
    test "a marketer-owned target is valid" do
      marketer = marketer!()
      assert %Target{} = target!(%{marketer_id: marketer.id})
    end

    test "a creator-owned target is valid" do
      creator = creator!()
      assert %Target{} = target!(%{creator_id: creator.id})
    end

    test "a target with no owner is rejected" do
      changeset = Target.changeset(%Target{}, %{title: "Orphan"})

      refute changeset.valid?

      assert "must belong to either a marketer or a creator" in errors_on(changeset).marketer_id
    end

    test "a target owned by both is rejected" do
      marketer = marketer!()
      creator = creator!()

      changeset =
        Target.changeset(%Target{}, %{
          title: "Both",
          marketer_id: marketer.id,
          creator_id: creator.id
        })

      refute changeset.valid?
      assert "cannot belong to both a marketer and a creator" in errors_on(changeset).creator_id
    end

    test "the same rule applies to trait_groups" do
      marketer = marketer!()
      creator = creator!()

      assert TraitGroup.changeset(%TraitGroup{}, %{title: "G", marketer_id: marketer.id}).valid?
      assert TraitGroup.changeset(%TraitGroup{}, %{title: "G", creator_id: creator.id}).valid?
      refute TraitGroup.changeset(%TraitGroup{}, %{title: "G"}).valid?

      refute TraitGroup.changeset(%TraitGroup{}, %{
               title: "G",
               marketer_id: marketer.id,
               creator_id: creator.id
             }).valid?
    end

    test "the database rejects a two-owner row even when the changeset is bypassed" do
      marketer = marketer!()
      creator = creator!()

      # `Ecto.Changeset.change/2` skips validation, so this reaches the
      # `exactly_one_owner` CHECK directly.
      assert_raise Ecto.ConstraintError, ~r/exactly_one_owner/, fn ->
        %Target{}
        |> Ecto.Changeset.change(%{
          title: "Bypass",
          marketer_id: marketer.id,
          creator_id: creator.id
        })
        |> Repo.insert()
      end
    end

    test "the database rejects an ownerless row even when the changeset is bypassed" do
      assert_raise Ecto.ConstraintError, ~r/exactly_one_owner/, fn ->
        %Target{}
        |> Ecto.Changeset.change(%{title: "Bypass"})
        |> Repo.insert()
      end
    end
  end

  describe "is_frozen?/1" do
    setup do
      marketer = marketer!()
      target = target!(%{marketer_id: marketer.id})

      band =
        %TargetBand{}
        |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
        |> Repo.insert!()

      %{marketer: marketer, target: target, band: band}
    end

    defp populate!(band) do
      me_file = Repo.insert!(%MeFile{})

      %TargetPopulation{}
      |> TargetPopulation.changeset(%{
        target_band_id: band.id,
        me_file_id: me_file.id,
        matching_tags_snapshot: %{}
      })
      |> Repo.insert!()
    end

    defp campaign!(marketer, target, attrs) do
      %Campaign{}
      |> Campaign.changeset(
        Map.merge(
          %{
            marketer_id: marketer.id,
            target_id: target.id,
            media_sequence_id: 1,
            title: "C #{System.unique_integer([:positive])}",
            start_date: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          },
          attrs
        )
      )
      |> Repo.insert!()
    end

    test "a populated target with no campaign is editable", %{target: target, band: band} do
      populate!(band)

      refute Targets.is_frozen?(target.id)
    end

    test "an unlaunched campaign does not freeze it", %{
      marketer: marketer,
      target: target,
      band: band
    } do
      populate!(band)
      campaign!(marketer, target, %{})

      refute Targets.is_frozen?(target.id)
    end

    test "a launched campaign freezes it", %{marketer: marketer, target: target} do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      campaign!(marketer, target, %{launched_at: now})

      assert Targets.is_frozen?(target.id)
    end

    test "a deactivated campaign releases it", %{marketer: marketer, target: target} do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      campaign!(marketer, target, %{launched_at: now, deactivated_at: now})

      refute Targets.is_frozen?(target.id)
    end

    test "a launched campaign against another target does not freeze this one", %{
      marketer: marketer,
      target: target
    } do
      other = target!(%{marketer_id: marketer.id})
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      campaign!(marketer, other, %{launched_at: now})

      refute Targets.is_frozen?(target.id)
      assert Targets.is_frozen?(other.id)
    end
  end

  describe "campaign target ownership" do
    test "a campaign cannot be created against another marketer's target" do
      buyer = marketer!()
      stranger = marketer!()
      foreign_target = target!(%{marketer_id: stranger.id})

      assert {:error, "Target does not belong to this marketer"} =
               Campaigns.create_campaign_with_ledger_and_bids(buyer.id, %{
                 "target_id" => foreign_target.id,
                 "title" => "Poach"
               })
    end

    test "a campaign cannot be created against a creator-owned content audience" do
      buyer = marketer!()
      creator = creator!()
      content_audience = target!(%{creator_id: creator.id})

      assert {:error, "Target does not belong to this marketer"} =
               Campaigns.create_campaign_with_ledger_and_bids(buyer.id, %{
                 "target_id" => content_audience.id,
                 "title" => "Promote"
               })
    end
  end
end
