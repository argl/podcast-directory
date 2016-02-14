defmodule Feeds.Mixfile do
  use Mix.Project

  def project do
    [app: :feeds,
     version: "1.0.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :hackney, :tzdata, :couch, :poolboy, :podcast_feeds],
     mod: {Feeds, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:couch, git: "https://github.com/argl/elixir-couch.git"},
      {:podcast_feeds, git: "https://github.com/argl/podcast-feeds.git"},
      {:timex, "~> 1.0.0-rc3"},
      {:cowboy, "~> 1.0.0", only: :test},
      {:hackney, "~> 1.4"},
      {:porcelain, "~> 2.0"},
      {:poolboy, "~> 1.5"},
      {:mix_test_watch, "~> 0.2", only: :dev},
      {:temp, "~> 0.3"}
    ]
  end
end
