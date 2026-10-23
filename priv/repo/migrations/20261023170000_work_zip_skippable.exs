defmodule Qlarius.Repo.Migrations.WorkZipSkippable do
  use Ecto.Migration

  def up do
    execute """
    UPDATE traits
    SET skip_exempt = TRUE
    WHERE parent_trait_id IS NULL
      AND input_type = 'single_select_zip'
      AND trait_name = 'Home Zip Code'
    """

    execute """
    UPDATE traits
    SET skip_exempt = FALSE
    WHERE parent_trait_id IS NULL
      AND input_type = 'single_select_zip'
      AND trait_name = 'Work Zip Code'
    """
  end

  def down do
    execute """
    UPDATE traits
    SET skip_exempt = TRUE
    WHERE parent_trait_id IS NULL
      AND input_type = 'single_select_zip'
      AND trait_name = 'Work Zip Code'
    """
  end
end
