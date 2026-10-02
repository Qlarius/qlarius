defmodule Qlarius.Sponster.Ads.AdCategory do
  @moduledoc """
  One row of the flat Sponster advertiser taxonomy. A category is the set of
  rows sharing a `category_id`; `ad_label` is the text shown on ads.

  Includes material from the IAB Tech Lab Ad Product Taxonomy 2.0, licensed
  under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Ads.MediaPiece

  @primary_key {:id, :id, autogenerate: true}

  @editable_fields ~w(ad_label category_name category_label age_gated age_min
                      sales_channel_default meta_1 meta_2 meta_3 sort_order cohort active)a

  @sales_channels ~w(local online both)
  @age_mins [18, 21]
  @ad_label_max 46

  schema "ad_categories" do
    field :row_id, :string
    field :category_id, :string
    field :category_name, :string
    field :category_label, :string
    field :ad_label, :string
    field :age_gated, :boolean, default: false
    field :age_min, :integer
    field :sales_channel_default, :string
    field :meta_1, :string
    field :meta_2, :string
    field :meta_3, :string
    field :sort_order, :integer
    field :cohort, :string
    field :active, :boolean, default: true

    field :media_pieces_count, :integer, virtual: true, default: 0
    field :active_media_pieces_count, :integer, virtual: true, default: 0

    has_many :media_pieces, MediaPiece
  end

  def sales_channels, do: @sales_channels
  def age_mins, do: @age_mins
  def ad_label_max, do: @ad_label_max
  def editable_fields, do: @editable_fields

  def create_changeset(category, attrs) do
    category
    |> cast(attrs, [:row_id, :category_id | @editable_fields])
    |> validate_required([:row_id, :category_id])
    |> validate_format(:row_id, ~r/^[A-Z0-9]+-\d{2,}$/)
    |> validate_format(:category_id, ~r/^[A-Z0-9]+$/)
    |> unique_constraint(:row_id)
    |> common_validations()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, @editable_fields)
    |> common_validations()
  end

  defp common_validations(changeset) do
    changeset
    |> update_change(:ad_label, &(&1 && String.trim(&1)))
    |> validate_required([:ad_label, :category_name, :category_label, :cohort, :sort_order])
    |> validate_length(:ad_label, max: @ad_label_max)
    |> validate_no_em_dash([:ad_label, :category_name, :category_label])
    |> validate_inclusion(:sales_channel_default, @sales_channels)
    |> validate_age()
    |> validate_cohort()
    |> unique_constraint(:ad_label)
    |> check_constraint(:age_min, name: :ad_categories_age_min_check)
    |> check_constraint(:cohort, name: :ad_categories_cohort_check)
    |> check_constraint(:sales_channel_default,
      name: :ad_categories_sales_channel_default_check
    )
  end

  defp validate_age(changeset) do
    case {get_field(changeset, :age_gated), get_field(changeset, :age_min)} do
      {true, nil} -> add_error(changeset, :age_min, "is required when age gated")
      {true, min} when min in @age_mins -> changeset
      {true, _} -> add_error(changeset, :age_min, "must be 18 or 21")
      {_, nil} -> changeset
      {_, _} -> add_error(changeset, :age_min, "must be blank unless age gated")
    end
  end

  defp validate_cohort(changeset) do
    validate_change(changeset, :cohort, fn :cohort, cohort ->
      if valid_cohort?(cohort), do: [], else: [cohort: "must be legacy or YYMMDD-xxxx"]
    end)
  end

  def valid_cohort?("legacy"), do: true

  def valid_cohort?(<<yy::binary-2, mm::binary-2, dd::binary-2, "-", suffix::binary-4>>) do
    String.match?(suffix, ~r/^[a-z0-9]{4}$/) and
      match?({:ok, _}, Date.from_iso8601("20#{yy}-#{mm}-#{dd}"))
  end

  def valid_cohort?(_), do: false

  defp validate_no_em_dash(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      validate_change(acc, field, fn ^field, value ->
        if is_binary(value) and String.contains?(value, "\u2014"),
          do: [{field, "must not contain em dashes"}],
          else: []
      end)
    end)
  end
end
