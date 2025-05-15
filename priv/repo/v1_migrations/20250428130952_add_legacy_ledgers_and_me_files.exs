defmodule Qlarius.Repo.Migrations.AddLegacyLedgersAndMeFiles do
  use Ecto.Migration

  def change do
    rename table(:ledger_entries), to: table(:ledger_entries_old)
    rename table(:ledger_headers), to: table(:ledger_headers_old)

    execute """
              DO $$
              BEGIN
              CREATE TABLE public.ledger_entries (
                id bigint NOT NULL PRIMARY KEY,
                amt numeric(8,2),
                description character varying(255),
                is_payable boolean,
                ledger_header_id bigint,
                ad_event_id bigint,
                transfer_event_id bigint,
                payout_event_id bigint,
                running_balance numeric(8,2),
                running_balance_payable numeric(8,2),
                created_at timestamp(6) without time zone NOT NULL,
                updated_at timestamp(6) without time zone NOT NULL
            );
            CREATE TABLE public.ledger_headers (
                id bigint NOT NULL PRIMARY KEY,
                description character varying(255),
                balance numeric(10,2),
                balance_payable numeric(10,2),
                me_file_id bigint,
                campaign_id bigint,
                recipient_id bigint,
                marketer_id bigint,
                created_at timestamp(6) without time zone NOT NULL,
                updated_at timestamp(6) without time zone NOT NULL
            );
            CREATE TABLE public.me_files (
                id bigint NOT NULL PRIMARY KEY,
                user_id bigint,
                display_name character varying(75),
                date_of_birth date,
                ledger_header_id bigint,
                sponster_token character varying(50),
                split_amount integer DEFAULT 50,
                referral_id bigint,
                referral_code character varying(255),
                created_at timestamp(6) without time zone NOT NULL,
                updated_at timestamp(6) without time zone NOT NULL
            );
            ALTER TABLE public.ledger_entries
              ADD CONSTRAINT fk_ledger_entries_ledger_header
              FOREIGN KEY (ledger_header_id)
              REFERENCES public.ledger_headers (id)
              ON DELETE RESTRICT;
            ALTER TABLE public.ledger_headers
              ADD CONSTRAINT fk_ledger_headers_me_file
              FOREIGN KEY (me_file_id)
              REFERENCES public.me_files (id)
              ON DELETE SET NULL;
            ALTER TABLE public.ledger_headers
              ADD CONSTRAINT fk_ledger_headers_recipient
              FOREIGN KEY (recipient_id)
              REFERENCES public.users (id)
              ON DELETE SET NULL;
            ALTER TABLE public.me_files
              ADD CONSTRAINT fk_me_files_user
              FOREIGN KEY (user_id)
              REFERENCES public.users (id)
              ON DELETE CASCADE;
            ALTER TABLE public.me_files
              ADD CONSTRAINT fk_me_files_ledger_header
              FOREIGN KEY (ledger_header_id)
              REFERENCES public.ledger_headers (id)
              ON DELETE SET NULL;
            END $$
            """,
            """
            DO $$
            BEGIN
            DROP TABLE public.ledger_entries;
            DROP TABLE public.ledger_headers;
            DROP TABLE public.me_files;
            END $$
            """
  end
end
