defmodule Qlarius.ApiRefTest do
  use ExUnit.Case, async: true

  alias Qlarius.ApiRef
  alias Qlarius.Sponster.Campaigns.Campaign

  test "valid? accepts the documented format only" do
    assert ApiRef.valid?("ptp-2610-joes_tacos-phx.campaign")
    assert ApiRef.valid?("ptp-2610-joes_tacos-phx.tg-2")
    refute ApiRef.valid?("ab")
    refute ApiRef.valid?("Has-Caps")
    refute ApiRef.valid?("-leading-dash")
    refute ApiRef.valid?(nil)
  end

  test "scope reads the area segment" do
    assert ApiRef.scope("ptp-2610-joes_tacos-nat.campaign") == "national"
    assert ApiRef.scope("ptp-2610-joes_tacos-phx.campaign") == "local"
    assert ApiRef.scope("ptp-2610-pet_barn-niche-pets.campaign") == "niche"
    assert ApiRef.scope("ptp-2610-pet_barn-niche-pets.campaign-v2") == "niche"
    assert ApiRef.scope("ptp-2610-joes_tacos.campaign") == "unscoped"
    assert ApiRef.scope(nil) == "unscoped"
  end

  describe "Campaign PTP defaults" do
    @base %{
      "marketer_id" => 1,
      "target_id" => 1,
      "media_sequence_id" => 1,
      "title" => "PTP",
      "start_date" => ~N[2026-10-03 00:00:00]
    }

    test "a new PTP campaign is non-payable and throttled" do
      changeset = Campaign.changeset(%Campaign{}, Map.put(@base, "is_ptp", true))
      assert Ecto.Changeset.get_field(changeset, :is_payable) == false
      assert Ecto.Changeset.get_field(changeset, :is_throttled) == true
    end

    test "explicit flags override the PTP defaults" do
      attrs = Map.merge(@base, %{"is_ptp" => true, "is_payable" => true, "is_throttled" => false})
      changeset = Campaign.changeset(%Campaign{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :is_payable) == true
      assert Ecto.Changeset.get_field(changeset, :is_throttled) == false
    end

    test "non-PTP and existing campaigns are left alone" do
      changeset = Campaign.changeset(%Campaign{}, @base)
      assert Ecto.Changeset.get_field(changeset, :is_throttled) == nil

      existing = %Campaign{id: 5, is_ptp: true, is_payable: true, is_throttled: false}
      changeset = Campaign.changeset(existing, %{"title" => "Renamed"})
      assert Ecto.Changeset.get_field(changeset, :is_payable) == true
      assert Ecto.Changeset.get_field(changeset, :is_throttled) == false
    end
  end
end
