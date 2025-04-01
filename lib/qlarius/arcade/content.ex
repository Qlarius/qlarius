defmodule Qlarius.Arcade.Content do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.TiqitType
  alias Qlarius.Arcade.Tiqit

  schema "content" do
    field :title, :string
    field :description, :string
    field :content_type, Ecto.Enum, values: ~w[video podcast blog]a, default: :video
    field :date_published, :date
    field :length, :integer, default: 0
    field :preview_length, :integer, default: 0
    field :file_url, :string, default: ""
    field :preview_url, :string, default: "http://example.com"
    field :price_default, :decimal, default: Decimal.new("0.00")

    has_many :tiqit_types, TiqitType
    has_many :tiqits, Tiqit

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
  end
end
