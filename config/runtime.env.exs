import Config

# Load .env variables (Dotenvy or similar)
if Code.ensure_loaded?(Dotenvy) do
  Dotenvy.load()
end

# Database config (always from env)
if db_url = System.get_env("DATABASE_URL") do
  config :qlarius, Qlarius.Repo, url: db_url
end
