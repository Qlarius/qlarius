defmodule Qlarius.Repo.Migrations.UpdateTraitsTableStructure do
  use Ecto.Migration

  def up do
    alter table(:traits) do
      add :is_active, :boolean, default: true
    end

    execute """
    UPDATE traits
    SET is_active = CASE
      WHEN active = 1 THEN true
      ELSE false
    END
    """

    alter table(:traits) do
      modify :is_active, :boolean, null: false, default: true
      remove :active
      remove :is_taggable
      remove :is_campaign_only
      remove :is_numeric
      remove :is_date
      remove :immutable
      remove :max_selected
    end

    execute """
    UPDATE traits
    SET input_type = CASE
      WHEN input_type = 'MultiSelect' THEN 'multi_select'
      WHEN input_type = 'SingleSelect' THEN 'single_select'
      WHEN input_type = 'MultiSelectList' THEN 'multi_select_list'
      WHEN input_type = 'SingleSelectZip' THEN 'single_select_zip'
      ELSE input_type
    END
    """
  end

  def down do
    execute """
    UPDATE traits
    SET input_type = CASE
      WHEN input_type = 'multi_select' THEN 'MultiSelect'
      WHEN input_type = 'single_select' THEN 'SingleSelect'
      WHEN input_type = 'multi_select_list' THEN 'MultiSelectList'
      WHEN input_type = 'single_select_zip' THEN 'SingleSelectZip'
      ELSE input_type
    END
    """

    alter table(:traits) do
      add :active, :integer
      add :is_taggable, :integer
      add :is_campaign_only, :boolean, default: false
      add :is_numeric, :boolean, default: false
      add :is_date, :boolean, default: false
      add :immutable, :boolean, default: false
      add :max_selected, :integer
    end

    execute """
    UPDATE traits
    SET active = CASE
      WHEN is_active = true THEN 1
      ELSE 0
    END
    """

    alter table(:traits) do
      modify :active, :integer, null: false
      remove :is_active
    end
  end
end
