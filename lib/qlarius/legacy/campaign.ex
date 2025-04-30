defmodule Qlarius.Legacy.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  schema "campaigns" do
    field :title, :string
    field :description, :string
    field :start_date, :naive_datetime
    field :end_date, :naive_datetime
    field :is_payable, :boolean
    field :is_throttled, :boolean
    field :is_demo, :boolean
    field :deactivated_at, :naive_datetime

    belongs_to :marketer, Qlarius.Legacy.Marketer
    belongs_to :target, Qlarius.Legacy.Target
    belongs_to :media_sequence, Qlarius.Legacy.MediaSequence

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :description,
      :start_date,
      :end_date,
      :is_payable,
      :is_throttled,
      :is_demo,
      :deactivated_at
    ])
    |> validate_required([
      :marketer_id,
      :title
    ])
  end
end
