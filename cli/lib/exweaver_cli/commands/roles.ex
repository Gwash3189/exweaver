defmodule ExweaverCli.Commands.Roles do
  @moduledoc """
  Role command (cli.md `roles list`). Roles are global read-only seed data;
  their names are what `customers invite --role` expects.
  """

  alias ExweaverCli.{Client, Error}
  alias ExweaverCli.Commands.Common

  @doc "List all roles."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, roles} <- Client.list("/roles", Common.opts(session)) do
      Common.render_list(roles, [:id, :name], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end
end
