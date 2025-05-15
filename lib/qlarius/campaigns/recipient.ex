defmodule Qlarius.Campaigns.Recipient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipients" do
    field :split_code, :string, autogenerate: {Ecto.UUID, :generate, []}
    field :name, :string
    field :description, :string
    field :message, :string
    field :target_amount, :decimal
    field :site_url, :string
    field :graphic_url, :string
    field :contact_email, :string
    field :approval_date, :naive_datetime
    field :referral_code, :string

    belongs_to :user, Qlarius.Accounts.User
    belongs_to :recipient_type, Qlarius.Campaigns.RecipientType
    belongs_to :approved_by_user, Qlarius.Accounts.User, foreign_key: :approved_by_user_id

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(recipient, attrs) do
    recipient
    |> cast(attrs, [
      :split_code,
      :user_id,
      :name,
      :description,
      :message,
      :target_amount,
      :site_url,
      :graphic_url,
      :recipient_type_id,
      :contact_email,
      :approval_date,
      :approved_by_user_id,
      :referral_code
    ])
    |> validate_required([
      :user_id,
      :name,
      :site_url,
      :recipient_type_id,
      :split_code
    ])
    |> validate_number(:target_amount, greater_than_or_equal_to: Decimal.new("0"))
  end
end
