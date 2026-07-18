defmodule ExweaverCli.Commands.EndUsers do
  @moduledoc """
  End-user commands (cli.md `end-users …`): `list`, `create`, `delete`.
  Identifiers are resolved to ids for deletion so users never type UUIDs.
  """

  alias ExweaverCli.{Client, Error, Resolver}
  alias ExweaverCli.Commands.Common

  @doc "List all end users."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, end_users} <- Client.list("/end_users", Common.opts(session)) do
      Common.render_list(end_users, [:identifier], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Create an end user by identifier."
  @spec create(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def create(identifier, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, end_user} <-
           Client.request(
             :post,
             "/end_users",
             Common.opts(session, json: %{identifier: identifier})
           ) do
      Common.render("Created end user #{identifier}", end_user, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Delete an end user by identifier (confirms unless `--yes`)."
  @spec delete(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def delete(identifier, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, end_user_id} <- Resolver.end_user_id(session, identifier),
         :ok <- Common.confirm(opts, "Delete end user #{identifier}?"),
         {:ok, response} <-
           Client.request(:delete, "/end_users/#{end_user_id}", Common.opts(session)) do
      Common.render("Deleted end user #{identifier}", response, opts)
    else
      :aborted -> {:ok, "Aborted."}
      {:error, reason} -> Error.result(reason)
    end
  end
end
