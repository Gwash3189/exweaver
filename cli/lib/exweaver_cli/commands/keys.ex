defmodule ExweaverCli.Commands.Keys do
  @moduledoc """
  Access-key commands (cli.md `keys …`): `list`, `create`, `revoke`. Only sdk
  keys are created here — personal tokens come from `signup`/`login`. The
  plaintext token is shown once, at creation, and never again (`GET` never
  returns it). `revoke` takes the key id directly (the one place users type a
  UUID, per cli.md).
  """

  alias ExweaverCli.{Client, Error, Resolver}
  alias ExweaverCli.Commands.Common

  @doc "List all access keys (values are never returned by the API)."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, keys} <- Client.list("/access_keys", Common.opts(session)) do
      Common.render_list(keys, [:id, :name, :kind, :environment_id], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Create an sdk key in an environment (`--env`); prints the token once."
  @spec create(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def create(name, opts) do
    with {:ok, env_key} <- require_env(opts),
         {:ok, session} <- Common.session(),
         {:ok, env_id} <- Resolver.environment_id(session, env_key),
         {:ok, key} <-
           Client.request(
             :post,
             "/access_keys",
             Common.opts(session, json: %{name: name, kind: "sdk", environment_id: env_id})
           ) do
      message =
        "Created sdk key #{name}. Save this token now — it will not be shown again:\n\n" <>
          "  #{key["token"]}"

      Common.render(message, key, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Revoke an access key by id (confirms unless `--yes`)."
  @spec revoke(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def revoke(id, opts) do
    with {:ok, session} <- Common.session(),
         :ok <- Common.confirm(opts, "Revoke key #{id}?"),
         {:ok, response} <-
           Client.request(:delete, "/access_keys/#{id}", Common.opts(session)) do
      Common.render("Revoked key #{id}", response, opts)
    else
      :aborted -> {:ok, "Aborted."}
      {:error, reason} -> Error.result(reason)
    end
  end

  defp require_env(opts) do
    case Keyword.get(opts, :env) do
      nil -> {:error, :env_required}
      env_key -> {:ok, env_key}
    end
  end
end
