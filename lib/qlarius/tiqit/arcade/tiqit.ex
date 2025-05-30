defmodule Qlarius.Tiqit.Arcade.Tiqit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqits" do
    field :purchased_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :tiqit_class, Qlarius.Tiqit.Arcade.TiqitClass

    has_one :user, through: [:me_file, :user]
    has_one :content_piece, through: [:tiqit_class, :content_piece]

    timestamps()
  end

  def changeset(tiqit, attrs) do
    tiqit
    |> cast(attrs, ~w[purchased_at expires_at]a)
    |> validate_required(~w[purchased_at]a)
  end
end
