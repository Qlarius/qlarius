defmodule Qlarius.YouData.MeFiles.MeFileTraitNudge do
  use Ecto.Schema

  schema "me_file_trait_nudges" do
    field :shown_at, :utc_datetime

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :trait, Qlarius.YouData.Traits.Trait

    timestamps(type: :utc_datetime)
  end
end
