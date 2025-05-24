defmodule Qlarius.Repo.Migrations.UseLegacyUsers do
  use Ecto.Migration

  def change do
    # Renaming these instead of dropping them because it's easier than
    # untangling all the dependant tables and FKs. Revisit later.
    rename table(:users_tokens), to: table(:users_tokens_unused)
    rename table(:users), to: table(:users_unused)

    execute """
            CREATE TABLE public.users (
                id bigint NOT NULL PRIMARY KEY,
                username character varying(255) NOT NULL,
                email character varying(255) DEFAULT ''::character varying NOT NULL,
                encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
                reset_password_token character varying(255),
                reset_password_sent_at timestamp(6) without time zone,
                remember_created_at timestamp(6) without time zone,
                sign_in_count integer DEFAULT 0,
                current_sign_in_at timestamp(6) without time zone,
                last_sign_in_at timestamp(6) without time zone,
                current_sign_in_ip character varying(255),
                last_sign_in_ip character varying(255),
                confirmation_token character varying(255),
                confirmed_at timestamp(6) without time zone,
                confirmation_sent_at timestamp(6) without time zone,
                unconfirmed_email character varying(255),
                failed_attempts integer DEFAULT 0,
                unlock_token character varying(255),
                locked_at timestamp(6) without time zone,
                authentication_token character varying(255),
                created_at timestamp(6) without time zone NOT NULL,
                updated_at timestamp(6) without time zone NOT NULL,
                referrer_code character varying(255),
                role character varying,
                passage_id character varying,
                mobile_number character varying
            );
            """,
            "DROP TABLE public.users"
  end
end
