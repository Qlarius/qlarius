defmodule Qlarius.Campaigns.Target do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.{Campaign, TargetBand}

  schema "targets" do
    has_many :campaigns, Campaign
    has_many :target_bands, TargetBand, on_delete: :delete_all

    # belongs_to :marketer

    field :name, :string, source: :title
    field :description, :string

    belongs_to :created_by, Qlarius.Accounts.User, foreign_key: :user_created_by

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
  end
end
