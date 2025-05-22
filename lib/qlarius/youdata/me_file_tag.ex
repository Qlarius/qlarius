defmodule Qlarius.YouData.MeFileTag do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "me_file_tags" do
    belongs_to :me_file, Qlarius.YouData.MeFile
    belongs_to :trait_value, TraitValue, foreign_key: :trait_id

    field :tag_value, :string
    field :expiration_date, :date
    field :customized_hash, :string

    belongs_to :updated_by, Qlarius.Accounts.User, foreign_key: :modified_by
    belongs_to :inserted_by, Qlarius.Accounts.User, foreign_key: :added_by

    timestamps(
      type: :utc_datetime,
      inserted_at_source: :added_date,
      updated_at_source: :modified_date
    )
  end

  def changeset(me_file_tag, attrs) do
    me_file_tag
    |> cast(attrs, [:user_id, :trait_value_id])
    |> validate_required([:user_id, :trait_value_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:trait_value_id)
  end
end
