defmodule Qlarius.Sponster.Campaigns.Target do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.TargetBand

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "targets" do
    field :title, :string
    field :description, :string
    field :marketer_id, :integer
    field :user_created_by, :integer
    field :population_status, :string, default: "not_populated"
    field :last_populated_at, :naive_datetime

    has_many :target_bands, TargetBand

    timestamps()
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [
      :title,
      :description,
      :marketer_id,
      :user_created_by,
      :population_status,
      :last_populated_at
    ])
    |> validate_required([:title, :marketer_id])
    |> validate_inclusion(:population_status, ["not_populated", "populating", "populated"])
  end
end
