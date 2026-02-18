defmodule Qlarius.Sponster.Campaigns.TargetPopulation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.TargetBand
  alias Qlarius.YouData.MeFiles.MeFile

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "target_populations" do
    belongs_to :target_band, TargetBand
    belongs_to :me_file, MeFile

    field :matching_tags_snapshot, :map

    timestamps()
  end

  def changeset(target_population, attrs) do
    target_population
    |> cast(attrs, [:target_band_id, :me_file_id, :matching_tags_snapshot])
    |> validate_required([:target_band_id, :me_file_id, :matching_tags_snapshot])
    |> unique_constraint([:target_band_id, :me_file_id],
      name: :target_populations_target_band_id_me_file_id_index
    )
  end
end
