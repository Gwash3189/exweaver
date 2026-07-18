defmodule ExweaverWeb.Plugs.RequirePersonal do
  @moduledoc "Rejects sdk keys on management endpoints (rest_api.md)."

  alias ExweaverWeb.ErrorResponse

  def init(opts), do: opts

  def call(%{assigns: %{auth_kind: :personal}} = conn, _opts), do: conn

  def call(conn, _opts) do
    ErrorResponse.halt(
      conn,
      :forbidden,
      :forbidden,
      "This endpoint requires a personal access token."
    )
  end
end
