defmodule Qlarius.Tiqit.Arcade.Tiqit do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass

  schema "tiqits" do
    field :purchased_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :preserved, :boolean, default: false
    field :disconnected_at, :utc_datetime
    field :undone_at, :utc_datetime
    field :refund_locked_at, :utc_datetime
    field :price, :decimal
    field :duration_hours, :integer

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :tiqit_class, TiqitClass
    belongs_to :content_piece, ContentPiece
    belongs_to :content_group, ContentGroup
    belongs_to :catalog, Catalog

    has_one :user, through: [:me_file, :user]

    timestamps()
  end

  def changeset(tiqit, attrs) do
    tiqit
    |> cast(
      attrs,
      ~w[
        purchased_at expires_at preserved disconnected_at undone_at refund_locked_at
        me_file_id price duration_hours content_piece_id content_group_id catalog_id
      ]a
    )
    |> validate_required(~w[purchased_at]a)
  end

  def snapshot_attrs(%TiqitClass{} = class) do
    %{
      price: class.price,
      duration_hours: class.duration_hours,
      content_piece_id: class.content_piece_id,
      content_group_id: class.content_group_id,
      catalog_id: class.catalog_id
    }
  end

  def entitlement_class(%__MODULE__{} = tiqit) do
    %TiqitClass{
      id: tiqit.tiqit_class_id,
      price: tiqit.price,
      duration_hours: tiqit.duration_hours,
      content_piece_id: tiqit.content_piece_id,
      content_group_id: tiqit.content_group_id,
      catalog_id: tiqit.catalog_id
    }
  end

  def content_piece(%__MODULE__{content_piece: %ContentPiece{} = piece}), do: piece

  def content_piece(%__MODULE__{tiqit_class: %TiqitClass{content_piece: %ContentPiece{} = piece}}),
    do: piece

  def content_piece(_), do: nil

  def content_group(%__MODULE__{content_group: %ContentGroup{} = group}), do: group

  def content_group(%__MODULE__{tiqit_class: %TiqitClass{content_group: %ContentGroup{} = group}}),
    do: group

  def content_group(%__MODULE__{} = tiqit) do
    case content_piece(tiqit) do
      %ContentPiece{content_group: %ContentGroup{} = group} -> group
      _ -> nil
    end
  end

  def catalog(%__MODULE__{catalog: %Catalog{} = catalog}), do: catalog
  def catalog(%__MODULE__{tiqit_class: %TiqitClass{catalog: %Catalog{} = catalog}}), do: catalog

  def catalog(%__MODULE__{} = tiqit) do
    case content_group(tiqit) do
      %ContentGroup{catalog: %Catalog{} = catalog} -> catalog
      _ -> nil
    end
  end

  def scope_piece_id(%__MODULE__{content_piece_id: id}) when not is_nil(id), do: id
  def scope_piece_id(%__MODULE__{tiqit_class: %TiqitClass{content_piece_id: id}}), do: id
  def scope_piece_id(_), do: nil

  def scope_group_id(%__MODULE__{content_group_id: id}) when not is_nil(id), do: id
  def scope_group_id(%__MODULE__{tiqit_class: %TiqitClass{content_group_id: id}}), do: id
  def scope_group_id(_), do: nil

  def scope_catalog_id(%__MODULE__{catalog_id: id}) when not is_nil(id), do: id
  def scope_catalog_id(%__MODULE__{tiqit_class: %TiqitClass{catalog_id: id}}), do: id
  def scope_catalog_id(_), do: nil
end
