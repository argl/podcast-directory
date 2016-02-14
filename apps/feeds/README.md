# Feeds

Manages podcast feeds. fetch, parse, persist. Uses Apache Couchdb for storage. Part of the podcast directory
umbrella project.

## Installation

Add configuration files `config/test.exs` aand `config/dev.exs` with your databse config:

```elixir
use Mix.Config

config :couch, url: "http://andi:blabla@localhost:5984", db: "podcast-directory"
config :pd, print_events: false
```

Add the node dependencies with `npm install`


If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add feeds to your list of dependencies in `mix.exs`:

        def deps do
          [{:feeds, "~> 1.0.0"}]
        end

  2. Ensure feeds is started before your application:

        def application do
          [applications: [:feeds]]
        end

