defmodule ExweaverCli.Commands.Environments do
  @moduledoc """
  Environment commands (cli.md `envs …`): `list`, `create`, `delete`. Keys are
  resolved to ids for deletion so users never type UUIDs.
  """

  alias ExweaverCli.{Client, Error, Resolver}
  alias ExweaverCli.Commands.Common

  @doc "List all environments."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, environments} <- Client.list("/environments", Common.opts(session)) do
      Common.render_list(environments, [:key, :name], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Create an environment. `--name` defaults to the key."
  @spec create(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def create(key, opts) do
    attrs = %{key: key, name: Keyword.get(opts, :name, key)}

    with {:ok, session} <- Common.session(),
         {:ok, environment} <-
           Client.request(:post, "/environments", Common.opts(session, json: attrs)) do
      Common.render("Created environment #{key}", environment, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Delete an environment (confirms unless `--yes`). The last one cannot be deleted."
  @spec delete(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def delete(key, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, environment_id} <- Resolver.environment_id(session, key),
         :ok <- Common.confirm(opts, "Delete environment #{key}?"),
         {:ok, response} <-
           Client.request(:delete, "/environments/#{environment_id}", Common.opts(session)) do
      Common.render("Deleted environment #{key}", response, opts)
    else
      :aborted -> {:ok, "Aborted."}
      {:error, reason} -> Error.result(reason)
    end
  end
end
