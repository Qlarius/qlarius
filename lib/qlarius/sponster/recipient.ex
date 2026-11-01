defmodule Qlarius.Sponster.Recipient do
  use Ecto.Schema
  import Ecto.Changeset
  use Waffle.Ecto.Schema

  alias Qlarius.ApiRef

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
    field :api_ref, :string
    field :recipient_type_id, :integer, default: 1
    field :is_primary, :boolean, default: false
    field :archived_at, :utc_datetime

    belongs_to :creator, Qlarius.Creators.Creator
    belongs_to :user, Qlarius.Accounts.User
    # recipient_type_id stays a plain integer (1 = publisher, 2 = charity, and so on).
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
      :referral_code,
      :api_ref,
      :creator_id,
      :is_primary,
      :archived_at
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
    |> ApiRef.validate()
  end
end
