defmodule MangaEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :manga_ex,
      version: "0.1.0",
      elixir: "~> 1.10",
      config_path: "./configs/config.exs",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4.0"},

      # optional, but recommended adapter
      {:hackney, "~> 1.17.0"}
    ]
  end
end
