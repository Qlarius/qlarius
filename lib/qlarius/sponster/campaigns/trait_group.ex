defmodule Qlarius.Sponster.Campaigns.TraitGroup do
  @moduledoc """
  A reusable bundle of answer traits. On a band an `include` group admits
  anyone holding any of its traits; an `anti` group (an Anti-Trait Group)
  removes anyone holding any of its traits. The role is chosen at creation and
  never changes, since bands and population snapshots are built around it.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{Ownership, TraitGroupTrait, TargetBandTraitGroup}

  @roles ~w(include anti)

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "trait_groups" do
    field :title, :string
    field :description, :string
    field :parent_trait_id, :integer
    field :marketer_id, :integer
    field :creator_id, :integer
    field :user_created_by, :integer
    field :deactivated_at, :naive_datetime
    field :api_ref, :string
    field :role, :string, default: "include"

    has_many :trait_group_traits, TraitGroupTrait
    has_many :traits, through: [:trait_group_traits, :trait]

    has_many :target_band_trait_groups, TargetBandTraitGroup
    has_many :target_bands, through: [:target_band_trait_groups, :target_band]

    timestamps()
  end

  def roles, do: @roles

  def anti?(%{role: "anti"}), do: true
  def anti?(_group), do: false

  def changeset(trait_group, attrs) do
    trait_group
    |> cast(attrs, [
      :title,
      :description,
      :parent_trait_id,
      :marketer_id,
      :creator_id,
      :user_created_by,
      :deactivated_at,
      :api_ref,
      :role
    ])
    |> validate_required([:title, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_role_immutable()
    |> Ownership.validate_exactly_one_owner()
    |> Qlarius.ApiRef.validate()
  end

  defp validate_role_immutable(%{data: %{id: nil}} = changeset), do: changeset

  defp validate_role_immutable(changeset) do
    case fetch_change(changeset, :role) do
      {:ok, _new_role} ->
        add_error(changeset, :role, "cannot change after creation", reason: :role_immutable)

      :error ->
        changeset
    end
  end
end
