defmodule Qlarius.Sponster.Campaigns.MediaSequence do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "media_sequences" do
    field :title, :string
    field :active, :boolean, default: true

    belongs_to :campaign, Campaign
    has_many :media_runs, MediaRun

    timestamps()
  end

  def changeset(media_sequence, attrs) do
    media_sequence
    |> cast(attrs, [
      :title,
      :active,
      :campaign_id
    ])
    |> validate_required([
      :title,
      :campaign_id
    ])
    |> foreign_key_constraint(:campaign_id)
  end
end
