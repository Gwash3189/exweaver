defmodule ExweaverWeb.Plugs.Authorize do
  @moduledoc """
  The sole permission-by-method RBAC gate (decisions.md D28/D29). The required
  permission is derived from the HTTP method (rest_api.md: POST=create, GET=read,
  PATCH/PUT=update, DELETE=delete) and checked via `Exweaver.Accounts.authorize/2`,
  which delegates to `Exweaver.Accounts.Authorization` — the single home for the
  RBAC decision. Contexts do not re-check method-permission; they own company
  scoping and the admin-only rules permission-by-method can't express.
  """

  alias Exweaver.Accounts
  alias ExweaverWeb.ErrorResponse

  @permission_by_method %{
    "GET" => :read,
    "HEAD" => :read,
    "QUERY" => :read,
    "POST" => :create,
    "PUT" => :update,
    "PATCH" => :update,
    "DELETE" => :delete
  }

  def init(opts), do: opts

  def call(%{assigns: %{current_customer: customer}} = conn, _opts) do
    permission = Map.fetch!(@permission_by_method, conn.method)

    case Accounts.authorize(customer, permission) do
      :ok ->
        conn

      {:error, :unauthorized} ->
        ErrorResponse.halt(
          conn,
          :forbidden,
          :forbidden,
          "Your role does not permit this action."
        )
    end
  end
end
