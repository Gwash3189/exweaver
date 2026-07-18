defmodule ExweaverCli.Support.AuthStubPlug do
  @moduledoc """
  A minimal real Plug used by the auth integration spec: it stands in for the
  server's `POST /api/v1/auth/login`, echoing back a token. Booted under a real
  Bandit listener so the CLI's `Req` client exercises an actual HTTP round-trip
  (socket, headers, JSON), not the in-process `Req.Test` stub.
  """

  import Plug.Conn

  @token "exw_0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b_c2VjcmV0"

  def init(opts), do: opts

  def call(%Plug.Conn{method: "POST", path_info: ["api", "v1", "auth", "login"]} = conn, _opts) do
    {:ok, _body, conn} = read_body(conn)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(201, Jason.encode!(%{token: @token, expires_at: nil}))
  end

  def call(conn, _opts), do: send_resp(conn, 404, "not found")

  @doc "The fixed token the stub mints, so the spec can assert on it."
  def token, do: @token
end
