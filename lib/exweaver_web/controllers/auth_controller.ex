defmodule ExweaverWeb.AuthController do
  @moduledoc """
  Unauthenticated, ETS rate-limited signup/login (authentication.md). Returns
  a generic 422 for both an unknown email and an already-signed-up email so
  the response never reveals which case occurred (no enumeration).
  """

  use ExweaverWeb, :controller

  alias Exweaver.Accounts
  alias Exweaver.Accounts.Customer
  alias Exweaver.Auth
  alias Exweaver.Auth.RateLimiter
  alias ExweaverWeb.{ErrorResponse, Serializer}

  # Maps each valid `expires_in` string to its atom. Written as literals so the
  # atoms are materialized at compile time — `String.to_existing_atom/1` on
  # `"1d"`/`"7d"`/`"14d"`/`"90d"` would otherwise raise, since only `:"30d"` and
  # `:never` appear as literals elsewhere.
  @expires_in %{
    "1d" => :"1d",
    "7d" => :"7d",
    "14d" => :"14d",
    "30d" => :"30d",
    "90d" => :"90d",
    "never" => :never
  }
  @expires_in_values ~w(1d 7d 14d 30d 90d never)

  # authentication.md: "max 5 failed password attempts per email per 15 min"
  @failed_attempt_limit 5
  @failed_attempt_window :timer.minutes(15)

  # authentication.md calls for "per-IP caps on /auth/*" without a fixed number.
  @ip_limit 20
  @ip_window :timer.minutes(15)

  def signup(conn, params), do: authenticate(conn, params, :signup, &resolve_signup/2)

  def login(conn, params), do: authenticate(conn, params, :login, &resolve_login/2)

  # The single home for the signup/login choreography and its no-enumeration
  # invariant (authentication.md): IP rate-limit, expires_in parsing, credential
  # validation, token mint, and — critically — the one generic-failure path that
  # makes an unknown email, an already-/not-yet-signed-up account, and a wrong
  # password indistinguishable. Only the per-flow "resolve the customer" step
  # differs, so it is passed in as `resolve_fun`.
  defp authenticate(conn, params, action, resolve_fun) do
    email = params["email"]
    password = params["password"]

    with :ok <- check_ip_rate(conn),
         {:ok, expires_in} <- parse_expires_in(params["expires_in"]),
         true <- valid_credentials?(email, password),
         {:ok, customer} <- resolve_fun.(email, password),
         {:ok, access_key, token} <- Auth.mint_personal_token(customer, expires_in) do
      render_token(conn, access_key, token)
    else
      {:error, :rate_limited} -> too_many_requests(conn)
      {:error, :invalid_expires_in} -> invalid_expires_in(conn)
      _ -> generic_failure(conn, action, email)
    end
  end

  # Signup succeeds only against a pre-approved (NULL-password) customer.
  defp resolve_signup(email, password) do
    with %Customer{hashed_password: nil} = customer <- Accounts.get_customer_by_email(email),
         {:ok, customer} <- Accounts.set_password(customer, password) do
      {:ok, customer}
    else
      _ -> :error
    end
  end

  # Login succeeds only against a signed-up (non-NULL-password) customer whose
  # password verifies.
  defp resolve_login(email, password) do
    with %Customer{hashed_password: hash} = customer when not is_nil(hash) <-
           Accounts.get_customer_by_email(email),
         true <- Accounts.verify_password(customer, password) do
      {:ok, customer}
    else
      _ -> :error
    end
  end

  defp valid_credentials?(email, password) do
    is_binary(email) and is_binary(password) and password != ""
  end

  defp render_token(conn, access_key, token) do
    conn
    |> put_status(:created)
    |> json(%{token: token, expires_at: Serializer.iso8601(access_key.expired_at)})
  end

  defp generic_failure(conn, action, email) do
    case record_failed_attempt(action, email) do
      {:error, :rate_limited} ->
        too_many_requests(conn)

      :ok ->
        ErrorResponse.halt(
          conn,
          :unprocessable_entity,
          :invalid_credentials,
          "Invalid email or password."
        )
    end
  end

  defp record_failed_attempt(action, email) when is_binary(email) do
    RateLimiter.check_rate(
      "auth:#{action}:#{email}",
      @failed_attempt_limit,
      @failed_attempt_window
    )
  end

  defp record_failed_attempt(_action, _email), do: :ok

  defp check_ip_rate(conn) do
    RateLimiter.check_rate("auth:ip:#{ip_string(conn)}", @ip_limit, @ip_window)
  end

  defp ip_string(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()

  defp too_many_requests(conn) do
    ErrorResponse.halt(
      conn,
      :too_many_requests,
      :rate_limited,
      "Too many requests. Try again later."
    )
  end

  defp invalid_expires_in(conn) do
    ErrorResponse.halt(
      conn,
      :unprocessable_entity,
      :invalid_expires_in,
      "expires_in must be one of: #{Enum.join(@expires_in_values, ", ")}."
    )
  end

  defp parse_expires_in(nil), do: {:ok, :"30d"}

  defp parse_expires_in(value) when is_map_key(@expires_in, value) do
    {:ok, Map.fetch!(@expires_in, value)}
  end

  defp parse_expires_in(_value), do: {:error, :invalid_expires_in}
end
