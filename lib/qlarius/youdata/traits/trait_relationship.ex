defmodule Qlarius.YouData.Traits.TraitRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Traits.Trait

  @kinds ~w(conflicts requires)

  schema "trait_relationships" do
    field :kind, :string
    field :note, :string

    belongs_to :trait, Trait
    belongs_to :related_trait, Trait

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:trait_id, :related_trait_id, :kind, :note])
    |> update_change(:note, &blank_note/1)
    |> validate_required([:trait_id, :related_trait_id, :kind])
    |> validate_inclusion(:kind, @kinds)
    |> canonicalize_conflict()
    |> validate_not_self()
    |> foreign_key_constraint(:trait_id)
    |> foreign_key_constraint(:related_trait_id)
    |> unique_constraint([:trait_id, :related_trait_id, :kind],
      name: :trait_relationships_pair_kind_index,
      message: "already exists"
    )
  end

  # A conflict is the same either way, so store the smaller id first.
  defp canonicalize_conflict(changeset) do
    if get_field(changeset, :kind) == "conflicts" do
      left = get_field(changeset, :trait_id)
      right = get_field(changeset, :related_trait_id)

      if is_integer(left) and is_integer(right) and left > right do
        changeset
        |> put_change(:trait_id, right)
        |> put_change(:related_trait_id, left)
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_not_self(changeset) do
    left = get_field(changeset, :trait_id)
    right = get_field(changeset, :related_trait_id)

    if is_integer(left) and left == right do
      add_error(changeset, :related_trait_id, "must be a different trait")
    else
      changeset
    end
  end

  defp blank_note(nil), do: nil

  defp blank_note(note) when is_binary(note) do
    case String.trim(note) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_note(note), do: note
end
