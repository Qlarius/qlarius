defmodule Qlarius.TargetingFixtures do
  @moduledoc """
  Fixtures for traits, trait groups, targets and me_file tagging.

  These build rows directly rather than going through context functions, because
  the targeting tables are Rails-era and several of their audit columns are
  NOT NULL with no default and no changeset support. Building them here keeps
  that noise out of the tests.
  """

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    Target,
    TargetBand,
    TargetBandTraitGroup,
    TraitGroup,
    TraitGroupTrait
  }

  alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  alias Qlarius.YouData.Traits.Trait

  # `traits` and `me_file_tags` require audit columns that nothing in the app
  # sets; 0 stands in for "created by the system".
  @system_user 0

  defp unique(prefix), do: "#{prefix} #{System.unique_integer([:positive])}"

  def marketer_fixture(attrs \\ %{}) do
    %Marketer{}
    |> Marketer.changeset(Enum.into(attrs, %{business_name: unique("Marketer")}))
    |> Repo.insert!()
  end

  def creator_fixture(attrs \\ %{}) do
    %Creator{}
    |> Creator.changeset(Enum.into(attrs, %{name: unique("Creator")}))
    |> Repo.insert!()
  end

  @doc """
  A parent trait, i.e. the question. Children are the answers.
  """
  def parent_trait_fixture(name \\ nil) do
    Repo.insert!(%Trait{
      trait_name: name || unique("Question"),
      display_order: 1,
      is_active: true,
      input_type: "multi_select",
      added_by: @system_user,
      modified_by: @system_user
    })
  end

  def trait_fixture(parent, name \\ nil, display_order \\ 1) do
    Repo.insert!(%Trait{
      trait_name: name || unique("Answer"),
      parent_trait_id: parent.id,
      display_order: display_order,
      is_active: true,
      input_type: "multi_select",
      added_by: @system_user,
      modified_by: @system_user
    })
  end

  @doc """
  A trait group holding `traits`. Owner is `marketer_id` or `creator_id`.
  """
  def trait_group_fixture(owner, traits) do
    group =
      %TraitGroup{}
      |> TraitGroup.changeset(Enum.into(owner, %{title: unique("Group")}))
      |> Repo.insert!()

    for trait <- traits do
      %TraitGroupTrait{}
      |> TraitGroupTrait.changeset(%{trait_group_id: group.id, trait_id: trait.id})
      |> Repo.insert!()
    end

    group
  end

  @doc """
  A target with one band per entry in `band_specs`, each a list of trait groups.

  Bands are given outermost first: the last spec becomes the bullseye. A band
  matches a me_file that holds a trait from *every* one of its groups, so more
  groups means more restrictive.
  """
  def target_fixture(owner, band_specs) do
    target =
      %Target{}
      |> Target.changeset(Enum.into(owner, %{title: unique("Target")}))
      |> Repo.insert!()

    last = length(band_specs) - 1

    for {groups, index} <- Enum.with_index(band_specs) do
      band =
        %TargetBand{}
        |> TargetBand.changeset(%{
          target_id: target.id,
          is_bullseye: if(index == last, do: "1", else: "0")
        })
        |> Repo.insert!()

      for group <- groups do
        Repo.insert!(%TargetBandTraitGroup{target_band_id: band.id, trait_group_id: group.id})
      end
    end

    target
  end

  def me_file_fixture(traits \\ []) do
    me_file = Repo.insert!(%MeFile{})
    tag_me_file!(me_file, traits)
    me_file
  end

  def tag_me_file!(me_file, traits) do
    for trait <- traits do
      %MeFileTag{}
      |> MeFileTag.changeset(%{
        me_file_id: me_file.id,
        trait_id: trait.id,
        tag_value: trait.trait_name,
        added_by: @system_user,
        modified_by: @system_user
      })
      |> Repo.insert!()
    end

    me_file
  end
end
