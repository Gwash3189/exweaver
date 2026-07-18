defmodule ExweaverWeb.RoleController do
  @moduledoc "Read-only listing of global seed roles (rest_api.md, decisions.md D11)."

  use ExweaverWeb, :controller

  alias Exweaver.Accounts
  alias ExweaverWeb.{FallbackController, PaginationParams, Serializer}

  def index(conn, params) do
    case PaginationParams.parse(params) do
      {:ok, opts} ->
        {roles, next_cursor} = Accounts.list_roles(opts)
        json(conn, Serializer.page(roles, next_cursor, &Serializer.role/1))

      {:error, reason} ->
        FallbackController.call(conn, {:error, reason})
    end
  end
end
