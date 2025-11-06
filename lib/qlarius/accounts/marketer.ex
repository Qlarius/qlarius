defmodule Qlarius.Accounts.Marketer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  schema "marketers" do
    field :business_name, :string
    field :business_url, :string
    field :contact_first_name, :string
    field :contact_last_name, :string
    field :contact_number, :string
    field :contact_email, :string
    field :sic_code, :string

    has_many :campaigns, Qlarius.Sponster.Campaigns.Campaign
    has_many :media_sequences, Qlarius.Sponster.Campaigns.MediaSequence
    has_many :media_runs, Qlarius.Sponster.Campaigns.MediaRun
    has_many :marketer_users, Qlarius.Accounts.MarketerUser
    has_many :users, through: [:marketer_users, :user]

    timestamps()
  end

  def changeset(marketer, attrs) do
    marketer
    |> cast(attrs, [
      :business_name,
      :business_url,
      :contact_first_name,
      :contact_last_name,
      :contact_number,
      :contact_email,
      :sic_code
    ])
    |> validate_required([
      :business_name
    ])
  end
end
