defmodule Qlarius.Repo.Migrations.ExtendSponsterWidgetServeLogs do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Production inherited this table from the legacy database, so every step
  # here must also run cleanly when it already exists with rows.
  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS sponster_widget_serve_logs (
      id bigserial PRIMARY KEY,
      user_id bigint REFERENCES users(id),
      recipient_id bigint REFERENCES recipients(id),
      username character varying,
      user_email character varying,
      offers_count integer,
      offers_amount numeric,
      recipient_split_code character varying,
      recipient_referral_code character varying,
      ip_address character varying,
      host_page_url text,
      created_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL,
      browser character varying,
      device text,
      platform character varying
    )
    """)

    execute("""
    ALTER TABLE sponster_widget_serve_logs
      ADD COLUMN IF NOT EXISTS page_load_id uuid,
      ADD COLUMN IF NOT EXISTS connect_count integer NOT NULL DEFAULT 1,
      ADD COLUMN IF NOT EXISTS user_agent text,
      ADD COLUMN IF NOT EXISTS host character varying(255),
      ADD COLUMN IF NOT EXISTS authed boolean NOT NULL DEFAULT false
    """)

    execute("""
    UPDATE sponster_widget_serve_logs
    SET host = left(lower(substring(host_page_url FROM '^https?://([^/:?#]+)')), 255)
    WHERE host IS NULL AND host_page_url ~* '^https?://[^/:?#]+'
    """)

    create_if_not_exists unique_index(:sponster_widget_serve_logs, [:page_load_id, :recipient_id],
                           where: "page_load_id IS NOT NULL",
                           concurrently: true,
                           name: :sponster_widget_serve_logs_page_load_index
                         )

    for {columns, name} <- [
          {[:created_at], :sponster_widget_serve_logs_created_at_index},
          {[:recipient_id, :created_at], :sponster_widget_serve_logs_recipient_created_index},
          {[:ip_address, :created_at], :sponster_widget_serve_logs_ip_created_index},
          {[:host, :created_at], :sponster_widget_serve_logs_host_created_index}
        ] do
      create_if_not_exists index(:sponster_widget_serve_logs, columns,
                             concurrently: true,
                             name: name
                           )
    end
  end

  def down do
    for name <- [
          :sponster_widget_serve_logs_page_load_index,
          :sponster_widget_serve_logs_created_at_index,
          :sponster_widget_serve_logs_recipient_created_index,
          :sponster_widget_serve_logs_ip_created_index,
          :sponster_widget_serve_logs_host_created_index
        ] do
      drop_if_exists index(:sponster_widget_serve_logs, [], name: name, concurrently: true)
    end

    execute("""
    ALTER TABLE sponster_widget_serve_logs
      DROP COLUMN IF EXISTS page_load_id,
      DROP COLUMN IF EXISTS connect_count,
      DROP COLUMN IF EXISTS user_agent,
      DROP COLUMN IF EXISTS host,
      DROP COLUMN IF EXISTS authed
    """)
  end
end
