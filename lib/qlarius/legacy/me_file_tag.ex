defmodule Qlarius.Legacy.MeFileTag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.{MeFile, Trait}
  alias Qlarius.LegacyRepo

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]
  schema "me_file_tags" do
    field :tag_value, :string
    field :expiration_date, :naive_datetime
    field :modified_by, :integer
    field :added_by, :integer
    field :customized_hash, :map

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
      :expiration_date,
      :modified_by,
      :added_by,
      :customized_hash
    ])
    |> validate_required([
      :me_file_id,
      :trait_id,
      :expiration_date,
      :modified_by,
      :added_by
    ])
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:trait_id)
  end

  def tag_with_full_data(me_file_tag) do
    me_file_tag = LegacyRepo.preload(me_file_tag, trait: [:parent_trait])

    if me_file_tag.customized_hash && map_size(me_file_tag.customized_hash) > 0 do
      me_file_tag.customized_hash
    else
      {trait_holder, tag_value_holder} =
        if me_file_tag.trait.parent_trait do
          {me_file_tag.trait.parent_trait, me_file_tag.trait.trait_name}
        else
          {me_file_tag.trait, me_file_tag.tag_value}
        end

      data = %{
        tag_id: me_file_tag.id,
        tag_value: tag_value_holder,
        trait_id: trait_holder.id,
        trait_name: trait_holder.trait_name,
        trait_category_id: trait_holder.trait_category_id,
        trait_display_order: trait_holder.display_order
      }

      me_file_tag
      |> Ecto.Changeset.change(customized_hash: data)
      |> LegacyRepo.update!()

      data
    end
  end
end
