defmodule Qlarius.X.Campaigns.Target do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.{Campaign, TargetBand}

  schema "targets" do
    has_many :campaigns, Campaign
    has_many :target_bands, TargetBand, on_delete: :delete_all

    field :name, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
  end
end
