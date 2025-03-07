defmodule Qlarius.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.Target
  alias Qlarius.Marketing.MediaSequence

  schema "campaigns" do
    field :description, :string
    field :title, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :payable, :boolean, default: false
    field :throttled, :boolean, default: false
    field :demo, :boolean, default: false
    field :deactivated_at, :utc_datetime

    belongs_to :media_sequence, MediaSequence
    belongs_to :target, Target

    timestamps(type: :utc_datetime)
  end
end
