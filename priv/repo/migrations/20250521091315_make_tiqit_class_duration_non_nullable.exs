defmodule Qlarius.Repo.Migrations.MakeTiqitClassDurationNonNullable do
  use Ecto.Migration

  def change do
    execute """
            UPDATE tiqit_classes SET duration_hours = 24 WHERE duration_hours IS NULL;
            """,
            ""

    execute """
            ALTER TABLE tiqit_classes ALTER COLUMN duration_hours SET NOT NULL;
            """,
            """
            ALTER TABLE tiqit_classes ALTER COLUMN duration_hours DROP NOT NULL;
            """
  end
end
