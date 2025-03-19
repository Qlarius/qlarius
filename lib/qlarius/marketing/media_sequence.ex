defmodule Qlarius.Marketing.MediaSequence do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_sequences" do
    field :title, :string
    # TODO make the DB field nullable. I'm not sure we even need it;
    # I don't see a place in the Rails app that sets it anywhere:
    field :description, :string, default: ""

    timestamps()
  end

  @doc false
  def changeset(media_sequence, attrs) do
    media_sequence
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
