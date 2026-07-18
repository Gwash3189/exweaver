{:ok, _} = Application.ensure_all_started(:exweaver)

# Run every example inside a transaction that is rolled back afterwards, so specs
# stay isolated. Manual mode: each example checks a connection out in `before` and
# back in via `finally`.
Ecto.Adapters.SQL.Sandbox.mode(Exweaver.Repo, :manual)

ESpec.configure(fn config ->
  config.before(fn _tags ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Exweaver.Repo)
  end)

  config.finally(fn _shared ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Exweaver.Repo)
  end)
end)
