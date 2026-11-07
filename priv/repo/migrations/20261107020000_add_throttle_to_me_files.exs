defmodule Qlarius.Repo.Migrations.AddThrottleToMeFiles do
  use Ecto.Migration

  def up do
    alter table(:me_files) do
      add :throttle_ad_count, :integer, null: false, default: 3
      add :throttle_days, :integer, null: false, default: 7
    end

    flush()

    execute("""
    UPDATE me_files
    SET throttle_ad_count = COALESCE(#{global_int("THROTTLE_AD_COUNT")}, 3),
        throttle_days = COALESCE(#{global_int("THROTTLE_DAYS")}, 7)
    """)

    execute("""
    UPDATE me_files
    SET throttle_ad_count = COALESCE(#{global_int("PROXY_THROTTLE_AD_COUNT")}, 25),
        throttle_days = COALESCE(#{global_int("PROXY_THROTTLE_DAYS")}, 0)
    WHERE user_id IN (SELECT proxy_user_id FROM user_proxies)
    """)
  end

  def down do
    alter table(:me_files) do
      remove :throttle_ad_count
      remove :throttle_days
    end
  end

  defp global_int(name) do
    """
    (SELECT value::integer FROM global_variables
     WHERE name = '#{name}' AND value ~ '^[0-9]+$' LIMIT 1)
    """
  end
end
