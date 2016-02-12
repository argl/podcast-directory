ExUnit.start

Mix.Task.run "ecto.create", ~w(-r Admin.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Admin.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(Admin.Repo)

