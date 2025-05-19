defmodule Qlarius.Tiqit.Arcade.ContentPiece do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.TiqitType

  schema "content_pieces" do
    field :title, :string
    field :description, :string
    field :content_type, Ecto.Enum, values: ~w[video podcast blog song]a, default: :video
    field :date_published, :date
    field :length, :integer, default: 0
    field :preview_length, :integer, default: 0
    field :file_url, :string, default: ""
    field :preview_url, :string, default: "http://example.com"
    field :price_default, :decimal, default: Decimal.new("0.00")

    has_many :tiqit_types, TiqitType, on_replace: :delete
    many_to_many :content_groups, ContentGroup, join_through: "content_groups_content_pieces"

    timestamps()
  end

  def changeset(content, attrs) do
    content
    |> cast(attrs, [
      :title,
      :description,
      :content_type,
      :date_published,
      :length,
      :preview_length,
      :file_url,
      :preview_url,
      :price_default
    ])
    |> validate_required([
      :title,
      :description,
      :date_published
    ])
    |> validate_length(:title, max: 200)
    |> cast_assoc(
      :tiqit_types,
      drop_param: :tiqit_type_drop,
      sort_param: :tiqit_type_sort,
      with: &tiqit_type_changeset/2
    )
  end

  defp tiqit_type_changeset(tt, params) do
    tt
    |> cast(params, ~w[name duration_seconds price]a)
    |> validate_required([:name, :price])
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
  end
end
