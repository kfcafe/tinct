defmodule Tinct.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/kfcafe/tinct"

  def project do
    [
      app: :tinct,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Tinct",
      description: "A terminal UI framework for Elixir",
      package: package(),
      docs: docs(),
      test_coverage: test_coverage(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp test_coverage do
    [
      summary: [threshold: 90],
      # These nested widget model modules are pure structs/types with no
      # meaningful runtime behavior to cover. Some Elixir versions report them
      # as 0% covered, which makes CI coverage thresholds flaky.
      ignore_modules: [
        Tinct.Widgets.List.Model,
        Tinct.Widgets.ScrollView.Model,
        Tinct.Widgets.SplitPane.Model,
        Tinct.Widgets.Static.Model,
        Tinct.Widgets.StatusBar.Model,
        Tinct.Widgets.Table.Model,
        Tinct.Widgets.Tabs.Model,
        Tinct.Widgets.TextInput.Model,
        Tinct.Widgets.Tree.Model
      ]
    ]
  end

  defp docs do
    [
      main: "Tinct",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
