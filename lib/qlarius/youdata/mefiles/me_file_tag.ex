defmodule Qlarius.YouData.MeFiles.MeFileTag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.Repo

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]
  schema "me_file_tags" do
    field :tag_value, :string
    field :modified_by, :integer
    field :added_by, :integer
    field :customized_hash, :string

    belongs_to :me_file, MeFile
    belongs_to :trait, Trait

    timestamps()
  end

  def changeset(me_file_tag, attrs) do
    me_file_tag
    |> cast(attrs, [
      :me_file_id,
      :trait_id,
      :tag_value,
      :modified_by,
      :added_by,
      :customized_hash
    ])
    |> validate_required([
      :me_file_id,
      :trait_id
    ])
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:trait_id)
  end

  def tag_with_full_data(me_file_tag) do
    me_file_tag = Repo.preload(me_file_tag, trait: [:parent_trait])

    {trait_holder, tag_value_holder} =
      if me_file_tag.trait.parent_trait do
        {me_file_tag.trait.parent_trait, me_file_tag.trait.trait_name}
      else
        {me_file_tag.trait, me_file_tag.tag_value}
      end

    %{
      tag_id: me_file_tag.id,
      tag_value: tag_value_holder,
      trait_id: trait_holder.id,
      trait_name: trait_holder.trait_name,
      trait_category_id: trait_holder.trait_category_id,
      trait_display_order: trait_holder.display_order
    }
  end
end
