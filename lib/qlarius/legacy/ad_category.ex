defmodule Qlarius.Legacy.AdCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.MediaPiece

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
