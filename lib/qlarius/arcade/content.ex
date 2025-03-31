defmodule Qlarius.Arcade.Content do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.TiqitType
  alias Qlarius.Arcade.Tiqit

  schema "content" do
    field :title, :string
    field :description, :string
    field :content_type, :string
    field :date_published, :date
    field :length, :integer
    field :preview_length, :integer
    field :file_url, :string
    field :preview_url, :string
    field :price_default, :decimal

    has_many :tiqit_types, TiqitType
    has_many :tiqits, Tiqit

    timestamps()
  end

  def changeset(content, attrs) do
    content
    |> cast(attrs, [
      :marketer_id,
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
      :marketer_id,
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
    |> validate_length(:title, max: 200)
    |> validate_length(:content_type, max: 20)
    |> validate_length(:file_url, max: 500)
    |> validate_length(:preview_url, max: 500)
    |> assoc_constraint(:marketer)
  end
end
