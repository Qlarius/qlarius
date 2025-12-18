defmodule Qlarius.Accounts.AliasWord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alias_words" do
    field :word, :string
    field :type, :string
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(alias_word, attrs) do
    alias_word
    |> cast(attrs, [:word, :type, :active])
    |> validate_required([:word, :type])
    |> validate_inclusion(:type, ["adjective", "noun"])
    |> validate_format(:word, ~r/^[a-z]+$/, message: "must be lowercase letters only")
    |> validate_length(:word, min: 2, max: 20)
    |> unique_constraint([:word, :type])
  end
end

