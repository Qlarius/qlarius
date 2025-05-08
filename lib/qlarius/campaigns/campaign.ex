defmodule Qlarius.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.Target
  alias Qlarius.Marketing.MediaSequence

  schema "campaigns" do
    field :description, :string
    field :title, :string
    field :starts_at, :utc_datetime, source: :start_date
    field :ends_at, :utc_datetime, source: :end_date
    field :is_payable, :boolean, default: false
    field :is_throttled, :boolean, default: false
    field :is_demo, :boolean, default: false
    field :deactivated_at, :utc_datetime

    belongs_to :marketer, Qlarius.Accounts.Marketer

    # belongs_to :marketer
    belongs_to :media_sequence, MediaSequence
    belongs_to :target, Target

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end
end
