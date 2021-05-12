defmodule MangaEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :manga_ex,
      version: "./VERSION" |> File.read!() |> String.trim(),
      elixir: "~> 1.10",
      config_path: "./configs/config.exs",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  defp description do
    "Scrapper that download chapters whitout limits from some providers"
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* VERSION*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yashin5/manga_ex"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.4.0"},
      {:floki, "~> 0.30.0"},
      {:hackney, "~> 1.17.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
