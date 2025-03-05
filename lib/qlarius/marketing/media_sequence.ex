defmodule Qlarius.Marketing.MediaSequence do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_sequences" do
    field :title, :string
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(media_sequence, attrs) do
    media_sequence
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
