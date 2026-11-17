defmodule Qlarius.Repo.Migrations.AddWidgetThemes do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :ad_strip_theme, :string, null: false, default: "system"
      add :tip_jar_theme, :string, null: false, default: "system"
      add :arqade_theme, :string, null: false, default: "system"
    end

    alter table(:content_groups) do
      add :arqade_theme, :string
    end

    create constraint(:creators, :creators_ad_strip_theme,
             check: "ad_strip_theme in ('light', 'dark', 'system')"
           )

    create constraint(:creators, :creators_tip_jar_theme,
             check: "tip_jar_theme in ('light', 'dark', 'system')"
           )

    create constraint(:creators, :creators_arqade_theme,
             check: "arqade_theme in ('light', 'dark', 'system')"
           )

    create constraint(:content_groups, :content_groups_arqade_theme,
             check: "arqade_theme is null or arqade_theme in ('light', 'dark', 'system')"
           )
  end
end
