defmodule Qlarius.Sponster.Ads.AdCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Ads.MediaPiece

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ad_categories" do
    field :ad_category_name, :string

    has_many :media_pieces, MediaPiece
  end

  def changeset(ad_category, attrs) do
    ad_category
    |> cast(attrs, [:ad_category_name])
    |> validate_required([:ad_category_name])
  end
end

# TODO: Some form of integration with Shopify product taxonomies. Note that the Shopify product taxonomies are not exhaustive, so need to account for adding in our own taxonomy as well.
