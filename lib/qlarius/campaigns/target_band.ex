defmodule Qlarius.Campaigns.TargetBand do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.Target

  schema "target_bands" do
    belongs_to :target, Target

    field :title, :string
    field :description, :string
    field :bullseye, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(target_band, attrs) do
    target_band
    |> cast(attrs, [:title, :description, :bullseye, :target_id])
    |> validate_required([:title, :target_id])
  end
end
