defmodule Qlarius.Repo.Migrations.CreatePromoSequences do
  use Ecto.Migration

  def up do
    create table(:promo_sequences) do
      add :name, :string, null: false
      add :api_ref, :string
      add :global, :boolean, null: false, default: false
      add :is_default, :boolean, null: false, default: false
      add :max_height, :integer, null: false, default: 80
      add :bounce_image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:promo_sequences, [:api_ref], where: "api_ref IS NOT NULL")

    create unique_index(:promo_sequences, [:is_default],
             where: "is_default",
             name: :promo_sequences_one_default
           )

    create table(:promo_sequence_slides) do
      add :promo_sequence_id, references(:promo_sequences, on_delete: :delete_all), null: false
      add :track, :string, null: false
      add :position, :integer, null: false
      add :image, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:promo_sequence_slides, [:promo_sequence_id, :track, :position])

    alter table(:recipients) do
      add :promo_sequence_id, references(:promo_sequences, on_delete: :nilify_all)
    end

    create index(:recipients, [:promo_sequence_id])

    flush()
    seed()
  end

  def down do
    drop index(:recipients, [:promo_sequence_id])

    alter table(:recipients) do
      remove :promo_sequence_id
    end

    drop table(:promo_sequence_slides)
    drop table(:promo_sequences)
  end

  # The banners already on the announcer bar. Both tracks start as that one set.
  @banners [
    "uploads/recruiter_banners/DontReadThis_640.png",
    "uploads/recruiter_banners/LifeSponsored_640.png",
    "uploads/recruiter_banners/SellYourAttention_640.png"
  ]

  defp seed do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {1, [%{id: sequence_id}]} =
      repo().insert_all(
        "promo_sequences",
        [
          %{
            name: "Sponster",
            api_ref: "sponster",
            global: true,
            is_default: true,
            max_height: 80,
            bounce_image: nil,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    slides =
      for track <- ["wide", "narrow"], {image, position} <- Enum.with_index(@banners, 1) do
        %{
          promo_sequence_id: sequence_id,
          track: track,
          position: position,
          image: image,
          inserted_at: now,
          updated_at: now
        }
      end

    repo().insert_all("promo_sequence_slides", slides)
  end
end
