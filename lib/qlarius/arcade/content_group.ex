defmodule Qlarius.Arcade.ContentGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.Arcade.ContentGroupsPieces
  alias Qlarius.Arcade.ContentPiece

  schema "content_groups" do
    belongs_to :creator, User

    field :description, :string
    field :title, :string
    field :type, Ecto.Enum, values: ~w[show season album book class]a

    many_to_many :content_pieces, ContentPiece, join_through: ContentGroupsPieces

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end
end
