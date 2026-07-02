defmodule Xylem.MixProject do
  use Mix.Project

  def project do
    [
      app: :xylem,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [
        vcr: :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rdf, "~> 2.1"},
      {:sparql_client, "~> 0.5"},
      {:nimble_csv, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:hackney, "~> 1.17"},
      {:exvcr, "~> 0.15", only: :test},
      {:req_cassette, "~> 0.1", only: :test}
    ]
  end
end
