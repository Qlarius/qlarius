defmodule Qlarius.Arcade.ContentGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.Catalog
  alias Qlarius.Arcade.ContentPiece

  schema "content_groups" do
    belongs_to :catalog, Catalog

    field :description, :string
    field :title, :string
    field :type, Ecto.Enum, values: ~w[show season album book class]a

    has_many :content_pieces, ContentPiece

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end
end
