ESpec.start()

ESpec.configure(fn config ->
  config.before(fn _tags ->
    # Each example gets an isolated, throwaway XDG config home so credentials
    # specs read/write a real file (and assert its 0600 mode) without ever
    # touching the developer's `~/.config/exweaver/credentials`.
    tmp = Path.join(System.tmp_dir!(), "exweaver_cli_spec_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    snapshot = %{
      xdg: System.get_env("XDG_CONFIG_HOME"),
      server: System.get_env("EXWEAVER_SERVER")
    }

    System.put_env("XDG_CONFIG_HOME", tmp)
    # Never inherit the developer's real server override into an example.
    System.delete_env("EXWEAVER_SERVER")

    {:shared, xdg_home: tmp, env_snapshot: snapshot}
  end)

  config.finally(fn shared ->
    File.rm_rf!(shared.xdg_home)

    Enum.each(
      [
        {"XDG_CONFIG_HOME", shared.env_snapshot.xdg},
        {"EXWEAVER_SERVER", shared.env_snapshot.server}
      ],
      fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end
    )
  end)
end)
