defmodule ExweaverCli.Credentials do
  @moduledoc """
  Read/write the on-disk credentials file (`~/.config/exweaver/credentials`).

  Holds the configured server URL, the personal token, and the email the token
  was minted for (`whoami` uses it to find the caller in `GET /customers`, since
  the API has no `/me`). The file is written with mode `0600` (owner read/write
  only) since it stores a bearer token; the containing directory is `0700`.
  Location honors `XDG_CONFIG_HOME` when set, falling back to `~/.config`.
  """

  @enforce_keys []
  defstruct server: nil, token: nil, email: nil

  @type t :: %__MODULE__{
          server: String.t() | nil,
          token: String.t() | nil,
          email: String.t() | nil
        }

  @dir_mode 0o700
  @file_mode 0o600

  @doc "Absolute path to the credentials file."
  @spec path() :: String.t()
  def path do
    config_home = System.get_env("XDG_CONFIG_HOME") || Path.join(System.user_home!(), ".config")
    Path.join([config_home, "exweaver", "credentials"])
  end

  @doc "True when the credentials file exists on disk."
  @spec exists?() :: boolean()
  def exists?, do: File.exists?(path())

  @doc """
  Load the stored credentials. Returns an empty struct when the file is absent
  or unreadable/corrupt — callers treat "no credentials" and "bad credentials"
  identically (both mean "log in / set a server first").
  """
  @spec load() :: t()
  def load do
    with {:ok, contents} <- File.read(path()),
         {:ok, %{} = data} <- Jason.decode(contents) do
      %__MODULE__{server: data["server"], token: data["token"], email: data["email"]}
    else
      _ -> %__MODULE__{}
    end
  end

  @doc "Write the given credentials to disk, creating the directory as needed."
  @spec save(t()) :: :ok
  def save(%__MODULE__{} = credentials) do
    file = path()
    dir = Path.dirname(file)

    File.mkdir_p!(dir)
    _ = File.chmod(dir, @dir_mode)

    contents =
      Jason.encode!(%{
        server: credentials.server,
        token: credentials.token,
        email: credentials.email
      })

    File.write!(file, contents)
    File.chmod!(file, @file_mode)
    :ok
  end

  @doc """
  Merge the given fields into the stored credentials and persist. `nil` fields
  are ignored, so `put(token: "…")` leaves the stored server untouched.
  """
  @spec put(keyword() | map()) :: {:ok, t()}
  def put(attrs) do
    attrs = Map.new(attrs)
    current = load()

    updated = %__MODULE__{
      server: Map.get(attrs, :server) || current.server,
      token: Map.get(attrs, :token) || current.token,
      email: Map.get(attrs, :email) || current.email
    }

    :ok = save(updated)
    {:ok, updated}
  end

  @doc "Delete the credentials file. A no-op when it does not exist."
  @spec delete() :: :ok
  def delete do
    case File.rm(path()) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> raise File.Error, reason: reason, action: "remove", path: path()
    end
  end
end
