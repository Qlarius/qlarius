defmodule Qlarius.Tiqit.Arcade.ConsumerCreatorUndoCount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "consumer_creator_undo_counts" do
    field :count, :integer, default: 0

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :creator, Qlarius.Creators.Creator

    timestamps()
  end

  def changeset(undo_count, attrs) do
    undo_count
    |> cast(attrs, [:me_file_id, :creator_id, :count])
    |> validate_required([:me_file_id, :creator_id, :count])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> unique_constraint([:me_file_id, :creator_id])
  end
end
