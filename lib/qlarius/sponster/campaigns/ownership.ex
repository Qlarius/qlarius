defmodule Qlarius.Sponster.Campaigns.Ownership do
  @moduledoc """
  The shared ownership rule for targeting assets.

  Every `targets` and `trait_groups` row belongs to exactly one org —
  `marketer_id` XOR `creator_id`. Audiences never cross an org boundary; a user
  with membership on both sides copies them across instead. Enforced here for a
  usable error message and by an `exactly_one_owner` CHECK in the database so
  raw inserts cannot bypass it.
  """

  import Ecto.Changeset

  @doc """
  Validates that exactly one owner is set, and maps the database CHECK onto the
  same error so both layers report identically.
  """
  def validate_exactly_one_owner(changeset) do
    marketer_id = get_field(changeset, :marketer_id)
    creator_id = get_field(changeset, :creator_id)

    changeset
    |> owner_error(marketer_id, creator_id)
    |> check_constraint(:marketer_id,
      name: :exactly_one_owner,
      message: "must belong to exactly one of a marketer or a creator"
    )
  end

  defp owner_error(changeset, nil, nil) do
    add_error(changeset, :marketer_id, "must belong to either a marketer or a creator")
  end

  defp owner_error(changeset, marketer_id, creator_id)
       when not is_nil(marketer_id) and not is_nil(creator_id) do
    add_error(changeset, :creator_id, "cannot belong to both a marketer and a creator")
  end

  defp owner_error(changeset, _marketer_id, _creator_id), do: changeset
end
