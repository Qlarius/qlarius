defmodule Qlarius.Sponster.Campaigns.TargetSuggestionDismissal do
  @moduledoc """
  A marketer's "not for this target" on one topic of Anti-Trait Group
  suggestions. Keyed to the target and the excluded answers' parent, so the
  prompt stays quiet for that topic until they reopen it.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "target_suggestion_dismissals" do
    field :target_id, :integer
    field :parent_trait_id, :integer
    field :dismissed_at, :utc_datetime
  end

  def changeset(dismissal, attrs) do
    dismissal
    |> cast(attrs, [:target_id, :parent_trait_id, :dismissed_at])
    |> validate_required([:target_id, :parent_trait_id, :dismissed_at])
    |> unique_constraint([:target_id, :parent_trait_id])
  end
end
