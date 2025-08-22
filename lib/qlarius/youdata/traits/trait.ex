defmodule Qlarius.YouData.Traits.Trait do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Repo
  # Commented out unused aliases - MeFile/TraitGroup not directly referenced (through associations use atoms, not direct module references)
  # alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  # alias Qlarius.Sponster.Campaigns.{TraitGroup, TraitGroupTrait}
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.Sponster.Campaigns.TraitGroupTrait
  # TraitCategory commented - schema only in archive_hide
  alias Qlarius.YouData.Traits.TraitCategory

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]
  schema "traits" do
    field :trait_name, :string
    field :active, :integer
    field :is_taggable, :integer
    field :input_type, :string
    field :display_order, :integer
    field :is_campaign_only, :boolean, default: false
    field :is_numeric, :boolean, default: false
    field :modified_by, :integer
    field :added_by, :integer
    field :immutable, :boolean, default: false
    field :max_length, :integer
    field :max_selected, :integer
    field :is_date, :boolean, default: false

    belongs_to :parent_trait, __MODULE__, foreign_key: :parent_trait_id
    # TraitCategory association commented - schema only in archive_hide
    belongs_to :trait_category, TraitCategory

    has_many :child_traits, __MODULE__, foreign_key: :parent_trait_id
    has_many :me_file_tags, MeFileTag
    has_many :me_files, through: [:me_file_tags, :me_file]
    has_many :trait_group_traits, TraitGroupTrait
    has_many :trait_groups, through: [:trait_group_traits, :trait_group]

    timestamps()
  end

  def changeset(trait, attrs) do
    trait
    |> cast(attrs, [
      :trait_name,
      :active,
      :is_taggable,
      :input_type,
      :display_order,
      :parent_trait_id,
      :is_campaign_only,
      :is_numeric,
      :modified_by,
      :added_by,
      :trait_category_id,
      :immutable,
      :max_length,
      :max_selected,
      :is_date
    ])
    |> validate_required([
      :trait_name,
      :active,
      :is_taggable,
      :input_type,
      :display_order,
      :modified_by,
      :added_by
    ])
    |> foreign_key_constraint(:parent_trait_id)
    |> foreign_key_constraint(:trait_category_id)
  end

  def is_geo?(trait) do
    trait = Repo.preload(trait, :parent_trait)

    String.contains?(String.downcase(trait.trait_name), "zip code") ||
      (trait.parent_trait &&
         String.contains?(String.downcase(trait.parent_trait.trait_name), "zip code"))
  end
end
