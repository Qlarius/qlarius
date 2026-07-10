defmodule Qlarius.MeCP.Suggestions.TagSuggestion do
  @moduledoc """
  A tag proposal from a connected assistant, inert until the user answers the
  rendered question in the MeFile Builder (ground rule 1: nothing writes to a
  MeFile without explicit user confirmation).

  Grant-bound so the user always sees which counterparty suggested it and so
  revoking a grant can sweep its pending suggestions. `me_file_id` is the
  effective MeFile at suggestion time, so suggestions made while a proxy
  persona is active belong to that persona. `reason` is the assistant's own
  words, length-capped, and deleted with the row on dismiss.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Traits.Trait

  @statuses ~w(pending accepted dismissed)
  @reason_max_length 280

  @type t :: %__MODULE__{}

  schema "mecp_tag_suggestions" do
    field :proposed_values, {:array, :string}, default: []
    field :reason, :string
    field :status, :string, default: "pending"
    field :resolved_at, :utc_datetime

    belongs_to :grant, Grant, foreign_key: :mecp_grant_id
    belongs_to :me_file, MeFile
    belongs_to :trait, Trait

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def reason_max_length, do: @reason_max_length

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :mecp_grant_id,
      :me_file_id,
      :trait_id,
      :proposed_values,
      :reason,
      :status,
      :resolved_at
    ])
    |> validate_required([:mecp_grant_id, :me_file_id, :trait_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> truncate_reason()
    |> foreign_key_constraint(:mecp_grant_id)
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:trait_id)
    |> unique_constraint([:me_file_id, :trait_id], name: :mecp_tag_suggestions_pending_unique)
  end

  defp truncate_reason(changeset) do
    case get_change(changeset, :reason) do
      reason when is_binary(reason) ->
        put_change(changeset, :reason, String.slice(String.trim(reason), 0, @reason_max_length))

      _ ->
        changeset
    end
  end
end
