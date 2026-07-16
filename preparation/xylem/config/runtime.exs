import Config

config :xylem, :supabase,
  base_url: System.get_env("VITE_SUPABASE_URL"),
  api_key: System.get_env("SUPABASE_SERVICE_ROLE_KEY"),
  db: [schema: "public"]
