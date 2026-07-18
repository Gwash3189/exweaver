defmodule ExweaverWeb.ErrorResponse do
  @moduledoc "Renders the conventions.md error shape: %{error: %{code:, message:}}."

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc "Sets the status, renders the error JSON, and halts the plug pipeline."
  def halt(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
    |> halt()
  end
end
