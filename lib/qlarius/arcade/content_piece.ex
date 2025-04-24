defmodule Qlarius.Arcade.ContentPiece do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentGroupsPieces
  alias Qlarius.Arcade.TiqitType

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
    field :type, Ecto.Enum, values: ~w[episode chapter song piece lesson]a

    has_many :tiqit_types, TiqitType, on_replace: :delete
    many_to_many :content_groups, ContentGroup, join_through: ContentGroupsPieces

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
      with: &TiqitType.changeset/2
    )
  end
end
