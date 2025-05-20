defmodule Qlarius.Repo.Migrations.AddConstraintsToTiqitClasses do
  use Ecto.Migration

  def change do
    # ensure exactly one of catalog_id, content_group_id, or content_piece_id
    # is non-null
    execute """
    ALTER TABLE public.tiqit_classes
    ADD CONSTRAINT exactly_one_fk_non_null
    CHECK (
        (catalog_id IS NOT NULL)::int +
        (content_group_id IS NOT NULL)::int +
        (content_piece_id IS NOT NULL)::int = 1
    );
    """,
    """
    ALTER TABLE public.tiqit_classes
    DROP CONSTRAINT exactly_one_fk_non_null;
    """
  end
end
