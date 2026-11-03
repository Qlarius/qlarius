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
    belongs_to :promo_sequence, Qlarius.Sponster.PromoSequence
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
      :archived_at,
      :promo_sequence_id
    ])
    |> cast_attachments(attrs, [:graphic_url])
    |> maybe_assign_default_sequence()
    |> foreign_key_constraint(:promo_sequence_id)
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

  # New recipients take the current default. Later default changes, and
  # updates of recipients that already exist, leave promo_sequence_id alone.
  defp maybe_assign_default_sequence(changeset) do
    new? = Ecto.get_meta(changeset.data, :state) == :built

    chosen =
      get_change(changeset, :promo_sequence_id) || get_field(changeset, :promo_sequence_id)

    cond do
      not new? ->
        changeset

      not is_nil(chosen) ->
        changeset

      true ->
        case Qlarius.Sponster.PromoSequences.default_id() do
          nil -> changeset
          id -> put_change(changeset, :promo_sequence_id, id)
        end
    end
  end
end
