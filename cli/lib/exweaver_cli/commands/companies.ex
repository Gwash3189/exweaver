defmodule ExweaverCli.Commands.Companies do
  @moduledoc """
  Company commands (cli.md `companies create`). Create-only in v0 (D24 —
  admin-only, enforced server-side); creates the company, its default
  environments, and a pre-approved admin customer.
  """

  alias ExweaverCli.{Client, Error}
  alias ExweaverCli.Commands.Common

  @doc "Create a company with a pre-approved admin (`--admin-email`)."
  @spec create(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def create(name, opts) do
    with {:ok, admin_email} <- require_admin_email(opts),
         {:ok, session} <- Common.session(),
         {:ok, company} <-
           Client.request(
             :post,
             "/companies",
             Common.opts(session, json: %{name: name, admin_email: admin_email})
           ) do
      Common.render("Created company #{name} (admin: #{admin_email})", company, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  defp require_admin_email(opts) do
    case Keyword.get(opts, :admin_email) do
      nil -> {:error, :admin_email_required}
      email -> {:ok, email}
    end
  end
end
