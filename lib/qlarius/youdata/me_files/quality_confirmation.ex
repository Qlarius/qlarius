defmodule Qlarius.YouData.MeFiles.QualityConfirmation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  @kinds ~w(conflict count)

  schema "me_file_quality_confirmations" do
    field :kind, :string
    field :confirmed_at, :utc_datetime

    belongs_to :me_file, MeFile
    belongs_to :trait_relationship, TraitRelationship
    belongs_to :trait, Trait
  end

  def changeset(confirmation, attrs) do
    confirmation
    |> cast(attrs, [:me_file_id, :kind, :trait_relationship_id, :trait_id, :confirmed_at])
    |> validate_required([:me_file_id, :kind, :confirmed_at])
    |> validate_inclusion(:kind, @kinds)
    |> validate_shape()
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:trait_relationship_id)
    |> foreign_key_constraint(:trait_id)
    |> unique_constraint([:me_file_id, :trait_relationship_id],
      name: :me_file_quality_confirmations_conflict_index
    )
    |> unique_constraint([:me_file_id, :trait_id],
      name: :me_file_quality_confirmations_count_index
    )
  end

  defp validate_shape(changeset) do
    case get_field(changeset, :kind) do
      "conflict" ->
        changeset
        |> validate_required([:trait_relationship_id])
        |> put_change(:trait_id, nil)

      "count" ->
        changeset
        |> validate_required([:trait_id])
        |> put_change(:trait_relationship_id, nil)

      _ ->
        changeset
    end
  end
end
