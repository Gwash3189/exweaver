defmodule ExweaverCli.Resolver do
  @moduledoc """
  Resolves user-facing keys/identifiers to the UUIDs the API needs, so users
  never type UUIDs (cli.md). Each lookup lists the relevant collection and
  matches on the natural key.
  """

  alias ExweaverCli.Client
  alias ExweaverCli.Commands.Common

  @doc "Resolve a flag key to its id."
  @spec flag_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def flag_id(session, key), do: lookup(session, "/flags", "key", key, "flag")

  @doc "Resolve an environment key to its id."
  @spec environment_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def environment_id(session, key),
    do: lookup(session, "/environments", "key", key, "environment")

  @doc "Resolve a role name to its id."
  @spec role_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def role_id(session, name), do: lookup(session, "/roles", "name", name, "role")

  @doc "Resolve a customer email to its id."
  @spec customer_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def customer_id(session, email),
    do: lookup(session, "/customers", "email", email, "customer")

  @doc "Resolve an end-user identifier to its id (server-side `?identifier=` filter)."
  @spec end_user_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def end_user_id(session, identifier) do
    case Client.list("/end_users", Common.opts(session, params: %{identifier: identifier})) do
      {:ok, end_users} -> find(end_users, "identifier", identifier, "end user")
      {:error, _} = error -> error
    end
  end

  @doc """
  Resolve an end-user identifier to its id, creating the end_user if it does
  not exist yet (used by `flags assign` — evaluation never auto-creates, D13,
  but an explicit assignment should).
  """
  @spec resolve_or_create_end_user_id(Common.session(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def resolve_or_create_end_user_id(session, identifier) do
    case end_user_id(session, identifier) do
      {:ok, id} -> {:ok, id}
      {:error, {:not_found, _kind, _value}} -> create_end_user(session, identifier)
      {:error, _} = error -> error
    end
  end

  defp lookup(session, path, field, value, kind) do
    case Client.list(path, Common.opts(session)) do
      {:ok, items} -> find(items, field, value, kind)
      {:error, _} = error -> error
    end
  end

  defp find(items, field, value, kind) do
    case Enum.find(items, fn item -> item[field] == value end) do
      nil -> {:error, {:not_found, kind, value}}
      item -> {:ok, item["id"]}
    end
  end

  defp create_end_user(session, identifier) do
    case Client.request(
           :post,
           "/end_users",
           Common.opts(session, json: %{identifier: identifier})
         ) do
      {:ok, %{"id" => id}} -> {:ok, id}
      {:error, _} = error -> error
    end
  end
end
