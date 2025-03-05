defmodule Qlarius.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.Target
  alias Qlarius.Marketing.MediaSequence

  schema "campaigns" do
    field :description, :string
    field :title, :string

    belongs_to :media_sequence, MediaSequence
    belongs_to :target, Target

    timestamps(type: :utc_datetime)
  end
end
