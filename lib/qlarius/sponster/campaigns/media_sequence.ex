defmodule Qlarius.Sponster.Campaigns.MediaSequence do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun}
  alias Qlarius.Sponster.Marketer

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "media_sequences" do
    field :title, :string
    field :description, :string
    field :archived_at, :naive_datetime

    belongs_to :marketer, Marketer
    has_many :campaigns, Campaign
    has_many :media_runs, MediaRun

    timestamps()
  end

  def changeset(media_sequence, attrs) do
    media_sequence
    |> cast(attrs, [
      :title,
      :description,
      :marketer_id
    ])
    |> validate_required([
      :title,
      :marketer_id
    ])
    |> foreign_key_constraint(:marketer_id)
  end
end
