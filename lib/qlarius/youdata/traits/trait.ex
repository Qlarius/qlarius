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
    field :is_active, :boolean, default: true
    field :input_type, :string
    field :display_order, :integer
    field :modified_by, :integer
    field :added_by, :integer
    field :max_length, :integer

    belongs_to :parent_trait, __MODULE__, foreign_key: :parent_trait_id
    # TraitCategory association commented - schema only in archive_hide
    belongs_to :trait_category, TraitCategory
    has_one :survey_question, Qlarius.YouData.Surveys.SurveyQuestion, foreign_key: :trait_id
    has_one :survey_answer, Qlarius.YouData.Surveys.SurveyAnswer, foreign_key: :trait_id

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
      :is_active,
      :input_type,
      :display_order,
      :parent_trait_id,
      :modified_by,
      :added_by,
      :trait_category_id,
      :max_length
    ])
    |> validate_required([
      :trait_name,
      :is_active,
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
