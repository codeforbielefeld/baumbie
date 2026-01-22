import Config

config :exvcr,
  vcr_cassette_library_dir: "test/fixtures/vcr_cassettes"

config :logger, level: :warning
