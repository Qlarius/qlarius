defmodule Qlarius.Sponster.Recipient do
  use Ecto.Schema
  import Ecto.Changeset
  use Waffle.Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "recipients" do
    field :split_code, :string, autogenerate: {Ecto.UUID, :generate, []}
    field :name, :string
    field :description, :string
    field :message, :string
    field :target_amount, :decimal
    field :site_url, :string
    field :graphic_url, QlariusWeb.Uploaders.RecipientBrandImage.Type
    field :contact_email, :string
    field :approval_date, :naive_datetime
    field :referral_code, :string
    field :recipient_type_id, :integer, default: 1

    belongs_to :user, Qlarius.Accounts.User
    # RecipientType association commented - schema only in archive_hide
    # belongs_to :recipient_type, Qlarius.Sponster.RecipientType
    # allowing for recipient_type_id to be null for now and save as integer for now (1 = publisher default, 2 = charity, etc.)
    belongs_to :approved_by_user, Qlarius.Accounts.User, foreign_key: :approved_by_user_id

    timestamps()
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
      :recipient_type_id,
      :contact_email,
      :approval_date,
      :approved_by_user_id,
      :referral_code
    ])
    |> cast_attachments(attrs, [:graphic_url])
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
