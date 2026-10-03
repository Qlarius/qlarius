defmodule Qlarius.Repo.Migrations.AddIsPtpAndApiRefs do
  use Ecto.Migration

  @api_ref_tables ~w(marketers media_pieces trait_groups targets media_sequences campaigns)a

  def change do
    alter table(:campaigns) do
      add :is_ptp, :boolean, null: false, default: false
    end

    create index(:campaigns, [:is_ptp])

    for table <- @api_ref_tables do
      alter table(table) do
        add :api_ref, :string, size: 128
      end

      create unique_index(table, [:api_ref], where: "api_ref IS NOT NULL")
    end
  end
end
