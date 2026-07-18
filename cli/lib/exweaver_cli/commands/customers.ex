defmodule ExweaverCli.Commands.Customers do
  @moduledoc """
  Customer (team member) commands (cli.md `customers …`): `list`, `invite`,
  `reset-password`, `remove`. Role names and emails are resolved to ids via
  `ExweaverCli.Resolver` so users never type UUIDs.
  """

  alias ExweaverCli.{Client, Error, Resolver}
  alias ExweaverCli.Commands.Common

  @doc "List all team members."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, customers} <- Client.list("/customers", Common.opts(session)) do
      Common.render_list(customers, [:email, :role_id, :status], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Pre-approve a team member by email with a role name (`--role`)."
  @spec invite(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def invite(email, opts) do
    with {:ok, role_name} <- require_role(opts),
         {:ok, session} <- Common.session(),
         {:ok, role_id} <- Resolver.role_id(session, role_name),
         {:ok, customer} <-
           Client.request(
             :post,
             "/customers",
             Common.opts(session, json: %{email: email, role_id: role_id})
           ) do
      Common.render("Invited #{email} as #{role_name}", customer, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Clear a team member's password and revoke their tokens (admin-only, server-side)."
  @spec reset_password(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def reset_password(email, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, customer_id} <- Resolver.customer_id(session, email),
         {:ok, customer} <-
           Client.request(:post, "/customers/#{customer_id}/reset", Common.opts(session)) do
      Common.render("Reset password for #{email}", customer, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Remove a team member by email (confirms unless `--yes`)."
  @spec remove(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def remove(email, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, customer_id} <- Resolver.customer_id(session, email),
         :ok <- Common.confirm(opts, "Remove customer #{email}?"),
         {:ok, response} <-
           Client.request(:delete, "/customers/#{customer_id}", Common.opts(session)) do
      Common.render("Removed customer #{email}", response, opts)
    else
      :aborted -> {:ok, "Aborted."}
      {:error, reason} -> Error.result(reason)
    end
  end

  defp require_role(opts) do
    case Keyword.get(opts, :role) do
      nil -> {:error, :role_required}
      role_name -> {:ok, role_name}
    end
  end
end
