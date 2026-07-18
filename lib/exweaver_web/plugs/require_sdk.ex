defmodule ExweaverWeb.Plugs.RequireSdk do
  @moduledoc "Rejects personal tokens on evaluation endpoints (rest_api.md)."

  alias ExweaverWeb.ErrorResponse

  def init(opts), do: opts

  def call(%{assigns: %{auth_kind: :sdk}} = conn, _opts), do: conn

  def call(conn, _opts) do
    ErrorResponse.halt(
      conn,
      :forbidden,
      :forbidden,
      "This endpoint requires an sdk access key."
    )
  end
end
