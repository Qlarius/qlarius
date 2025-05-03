import Config

# Load .env variables (Dotenvy or similar)
if Code.ensure_loaded?(Dotenvy) do
  Dotenvy.load()
end

# Database config (always from env)
if db_url = System.get_env("DATABASE_URL") do
  config :qlarius, Qlarius.Repo, url: db_url
end

if legacy_db_url = System.get_env("LEGACY_DATABASE_URL") do
  config :qlarius, Qlarius.LegacyRepo, url: legacy_db_url
end
