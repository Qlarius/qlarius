defmodule Qlarius.Repo.Migrations.AddProxyPtpThrottleVariables do
  use Ecto.Migration

  def change do
    execute(
      """
      INSERT INTO global_variables (name, value)
      SELECT 'PROXY_THROTTLE_AD_COUNT', '25'
      WHERE NOT EXISTS (
        SELECT 1 FROM global_variables WHERE name = 'PROXY_THROTTLE_AD_COUNT'
      )
      """,
      "DELETE FROM global_variables WHERE name = 'PROXY_THROTTLE_AD_COUNT'"
    )

    execute(
      """
      INSERT INTO global_variables (name, value)
      SELECT 'PROXY_THROTTLE_DAYS', '0'
      WHERE NOT EXISTS (
        SELECT 1 FROM global_variables WHERE name = 'PROXY_THROTTLE_DAYS'
      )
      """,
      "DELETE FROM global_variables WHERE name = 'PROXY_THROTTLE_DAYS'"
    )
  end
end
