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
    field :meta_1, :string
    field :meta_2, :string
    field :meta_3, :string
    field :has_search_filter, :boolean, default: false
    field :is_skipped_tag, :boolean, default: false
    field :is_exclusive, :boolean, default: false
    field :skip_exempt, :boolean, default: false
    field :nudge_text, :string
    field :search_terms, {:array, :string}, default: []
    field :inserted_children, {:array, :map}, virtual: true, default: []
    field :ideal_min_tags, :integer
    field :ideal_max_tags, :integer
    field :hard_max_tags, :integer
    field :unripe_days, :integer
    field :ripen_days, :integer
    field :stale_days, :integer
    field :expired_days, :integer

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

  @max_search_terms 20
  @search_term_max_length 60

  def max_search_terms, do: @max_search_terms

  @quality_fields [
    :ideal_min_tags,
    :ideal_max_tags,
    :hard_max_tags,
    :unripe_days,
    :ripen_days,
    :stale_days,
    :expired_days
  ]

  def quality_fields, do: @quality_fields

  def changeset(trait, attrs) do
    trait
    |> cast(split_search_terms(blank_quality_inputs(attrs)), [
      :trait_name,
      :is_active,
      :input_type,
      :display_order,
      :parent_trait_id,
      :modified_by,
      :added_by,
      :trait_category_id,
      :max_length,
      :meta_1,
      :meta_2,
      :meta_3,
      :has_search_filter,
      :is_skipped_tag,
      :is_exclusive,
      :skip_exempt,
      :nudge_text,
      :search_terms
      | @quality_fields
    ])
    |> update_change(:nudge_text, &blank_to_nil/1)
    |> force_skip_exclusive()
    |> validate_required([
      :trait_name,
      :is_active,
      :input_type,
      :display_order,
      :modified_by,
      :added_by
    ])
    |> validate_quality_bounds()
    |> validate_count_rules_scope()
    |> normalize_search_terms()
    |> validate_length(:search_terms, max: @max_search_terms)
    |> foreign_key_constraint(:parent_trait_id)
    |> foreign_key_constraint(:trait_category_id)
  end

  # Admin forms send one comma-separated string; the API sends a list.
  defp split_search_terms(%{"search_terms" => terms} = attrs) when is_binary(terms),
    do: Map.put(attrs, "search_terms", String.split(terms, ","))

  defp split_search_terms(%{search_terms: terms} = attrs) when is_binary(terms),
    do: Map.put(attrs, :search_terms, String.split(terms, ","))

  defp split_search_terms(attrs), do: attrs

  defp blank_quality_inputs(attrs) when is_map(attrs) do
    Enum.reduce(@quality_fields, attrs, fn field, acc ->
      acc
      |> blank_quality_key(field)
      |> blank_quality_key(Atom.to_string(field))
    end)
  end

  defp blank_quality_inputs(attrs), do: attrs

  defp blank_quality_key(attrs, key) do
    if Map.has_key?(attrs, key) and attrs[key] in [nil, ""] do
      Map.put(attrs, key, nil)
    else
      attrs
    end
  end

  defp validate_quality_bounds(changeset) do
    changeset
    |> validate_non_negative(@quality_fields)
    |> validate_ordered(:ideal_min_tags, :ideal_max_tags, :lte, "must be at least ideal_min_tags")
    |> validate_ordered(:ideal_max_tags, :hard_max_tags, :lte, "must be at least ideal_max_tags")
    |> validate_ordered(:ideal_min_tags, :hard_max_tags, :lte, "must be at least ideal_min_tags")
    |> validate_ordered(:unripe_days, :ripen_days, :lte, "must be at least unripe_days")
    |> validate_ordered(:stale_days, :expired_days, :lte, "must be at least stale_days")
    |> validate_ordered(:ripen_days, :stale_days, :lt, "must be greater than ripen_days")
  end

  defp validate_non_negative(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      validate_number(acc, field, greater_than_or_equal_to: 0)
    end)
  end

  @count_fields [:ideal_min_tags, :ideal_max_tags, :hard_max_tags]

  defp validate_count_rules_scope(changeset) do
    any_count? = Enum.any?(@count_fields, &(get_field(changeset, &1) != nil))
    parent_id = get_field(changeset, :parent_trait_id)
    input_type = get_field(changeset, :input_type)

    cond do
      not any_count? ->
        changeset

      not is_nil(parent_id) ->
        add_error(changeset, :ideal_min_tags, "count rules belong on a multi_select parent")

      input_type != "multi_select" ->
        add_error(changeset, :ideal_min_tags, "count rules belong on a multi_select parent")

      true ->
        changeset
    end
  end

  defp force_skip_exclusive(changeset) do
    if get_field(changeset, :is_skipped_tag) do
      put_change(changeset, :is_exclusive, true)
    else
      changeset
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(text) when is_binary(text) do
    case String.trim(text) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(text), do: text

  defp validate_ordered(changeset, left, right, op, message) do
    a = get_field(changeset, left)
    b = get_field(changeset, right)

    ordered? =
      cond do
        not is_integer(a) or not is_integer(b) -> true
        op == :lte -> a <= b
        op == :lt -> a < b
      end

    if ordered?, do: changeset, else: add_error(changeset, right, message)
  end

  defp normalize_search_terms(changeset) do
    case get_change(changeset, :search_terms) do
      terms when is_list(terms) ->
        put_change(changeset, :search_terms, clean_search_terms(terms))

      _ ->
        changeset
    end
  end

  defp clean_search_terms(terms) do
    terms
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.slice(&1, 0, @search_term_max_length))
    |> Enum.uniq()
  end

  def is_geo?(trait) do
    trait = Repo.preload(trait, :parent_trait)

    String.contains?(String.downcase(trait.trait_name), "zip code") ||
      (trait.parent_trait &&
         String.contains?(String.downcase(trait.parent_trait.trait_name), "zip code"))
  end
end
