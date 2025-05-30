defmodule Qlarius.YouData.Traits.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "trait_values" do
    belongs_to :trait, Qlarius.YouData.Traits.Trait, foreign_key: :parent_trait_id

    field :name, :string, source: :trait_name
    field :active, :boolean
    field :is_taggable, :boolean, default: false
    field :input_type, :string
    field :display_order, :integer

    field :is_campaign_only, :boolean, default: false
    field :is_numeric, :boolean, default: true
    belongs_to :updated_by, Qlarius.Accounts.User, foreign_key: :modified_by
    belongs_to :inserted_by, Qlarius.Accounts.User, foreign_key: :added_by
    field :immutable, :boolean, default: false
    field :max_length, :integer
    field :max_selected, :integer
    field :is_date, :boolean, default: false

    field :answer, :string

    many_to_many :me_files, Qlarius.YouData.MeFile,
      join_through: Qlarius.YouData.MeFileTag,
      join_keys: [trait_id: :id, me_file_id: :id]

    timestamps(
      type: :utc_datetime,
      inserted_at_source: :added_date,
      updated_at_source: :modified_date
    )
  end

  @doc """
  Changeset for trait_value.
  """
  def changeset(trait_value, attrs) do
    trait_value
    |> cast(attrs, [:name, :display_order, :parent_trait_id, :answer])
    |> validate_required([:name, :display_order, :parent_trait_id])
  end
end
