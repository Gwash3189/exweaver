defmodule ExweaverWeb.Plugs.BearerAuth do
  @moduledoc """
  Parses the `Authorization: Bearer <token>` header and resolves it to either
  a personal-token customer or an sdk-key environment (authentication.md).
  """

  import Plug.Conn

  alias Exweaver.{Accounts, Auth, Flags}
  alias Exweaver.Auth.AccessKey
  alias ExweaverWeb.ErrorResponse

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- fetch_bearer_token(conn),
         {:ok, access_key} <- Auth.verify(token) do
      assign_actor(conn, access_key)
    else
      {:error, :token_expired} ->
        ErrorResponse.halt(conn, :unauthorized, :token_expired, "Access token has expired.")

      {:error, _reason} ->
        ErrorResponse.halt(conn, :unauthorized, :unauthorized, "Missing or invalid access token.")
    end
  end

  defp fetch_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp assign_actor(conn, %AccessKey{kind: :personal} = access_key) do
    case Accounts.get_customer(access_key.customer_id) do
      nil ->
        halt_unauthorized(conn)

      customer ->
        conn
        |> assign(:auth_kind, :personal)
        |> assign(:current_access_key, access_key)
        |> assign(:current_customer, customer)
    end
  end

  defp assign_actor(conn, %AccessKey{kind: :sdk} = access_key) do
    case Flags.get_environment(access_key.environment_id) do
      nil ->
        halt_unauthorized(conn)

      environment ->
        conn
        |> assign(:auth_kind, :sdk)
        |> assign(:current_access_key, access_key)
        |> assign(:current_environment, environment)
    end
  end

  defp halt_unauthorized(conn) do
    ErrorResponse.halt(conn, :unauthorized, :unauthorized, "Missing or invalid access token.")
  end
end
