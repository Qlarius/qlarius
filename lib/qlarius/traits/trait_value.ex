defmodule Qlarius.Traits.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "trait_values" do
    belongs_to :trait, Trait, source: :parent_trait_id

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

    many_to_many :me_files, Qlarius.Accounts.MeFile, join_through: Qlarius.Traits.MeFileTag

    timestamps(type: :utc_datetime,
      inserted_at_source: :added_date,
      updated_at_source: :modified_date
    )
  end

  @doc """
  Changeset for trait_value.
  """
  def changeset(trait_value, attrs) do
    trait_value
    |> cast(attrs, [:name, :display_order, :trait_id, :answer])
    |> validate_required([:name, :display_order, :trait_id])
  end
end
