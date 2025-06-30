defmodule ExESDBCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_esdb_cli,
      version: "0.0.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExESDBCli.App, []},
      extra_applications: [:logger, :ssh]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_esdb, "~> 0.0.16"},
      {:garnish, "~> 0.2.0"},
      {:table_rex, "~> 4.1.0"}
    ]
  end
end
