defmodule Qlarius.Repo.Migrations.AddActiveStorageTables do
  use Ecto.Migration

  # I thought we wouldn't need to copy the active storage tables from the Rails app but it turns out we do.

  def up do
    execute """
      DO $$
      BEGIN
      CREATE TABLE active_storage_attachments (
          id bigint NOT NULL,
          name character varying NOT NULL,
          record_type character varying NOT NULL,
          record_id bigint NOT NULL,
          blob_id bigint NOT NULL,
          created_at timestamp without time zone NOT NULL
      );

      CREATE TABLE active_storage_blobs (
          id bigint NOT NULL,
          key character varying NOT NULL,
          filename character varying NOT NULL,
          content_type character varying,
          metadata text,
          service_name character varying NOT NULL,
          byte_size bigint NOT NULL,
          checksum character varying NOT NULL,
          created_at timestamp without time zone NOT NULL
      );

      CREATE TABLE active_storage_variant_records (
          id bigint NOT NULL,
          blob_id bigint NOT NULL,
          variation_digest character varying NOT NULL
      );

      CREATE INDEX index_active_storage_attachments_on_blob_id ON active_storage_attachments USING btree (blob_id);

      CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON active_storage_attachments USING btree (record_type, record_id, name, blob_id);

      CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON active_storage_blobs USING btree (key);

      CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON active_storage_variant_records USING btree (blob_id, variation_digest);
      END $$
    """
  end

  def down do
    drop table(:active_storage_attachments)
    drop table(:active_storage_blobs)
    drop table(:active_storage_variant_records)
  end
end
