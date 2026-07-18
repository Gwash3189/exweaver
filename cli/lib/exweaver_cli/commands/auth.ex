defmodule ExweaverCli.Commands.Auth do
  @moduledoc """
  Auth commands (cli.md): `signup`, `login`, `logout`, `whoami`.

  Each returns a command result — `{:ok, output}` or
  `{:error, message, exit_code}` — for `ExweaverCli.CLI` to print and halt on.
  Commands are thin: the server validates credentials and the `expires_in`
  enum; the CLI only stores the returned token and formats output.
  """

  alias ExweaverCli.{ApiError, Client, Config, Credentials, Error, Output, Prompt, Token}

  @doc "Sign up a pre-approved email: sets the password and mints the first token."
  @spec signup(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def signup(email, opts), do: authenticate("/auth/signup", email, opts)

  @doc "Log in with an existing password and mint a new personal token."
  @spec login(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def login(email, opts), do: authenticate("/auth/login", email, opts)

  # Signup and login differ only in their endpoint: both take the email, prompt
  # for a password, POST it, and persist the returned token + email.
  defp authenticate(path, email, opts) do
    with {:ok, base_url} <- Config.server_url(),
         password = Prompt.password(),
         body = auth_body(email, password, opts),
         {:ok, %{"token" => token} = response} <-
           Client.request(:post, path, base_url: base_url, json: body) do
      {:ok, _} = Credentials.put(token: token, email: email)
      render_token(token, response, opts)
    else
      {:error, :no_server} -> Error.result(:no_server)
      {:error, %ApiError{} = error} -> Error.result(error)
    end
  end

  @doc "Revoke the current token server-side (best-effort) and delete the local file."
  @spec logout(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def logout(_opts) do
    case Credentials.load() do
      %Credentials{token: nil} ->
        {:ok, "Not logged in."}

      %Credentials{token: token} ->
        _ = revoke_remote(token)
        :ok = Credentials.delete()
        {:ok, "Logged out."}
    end
  end

  @doc "Show the currently-authenticated customer (found by the stored login email)."
  @spec whoami(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def whoami(opts) do
    credentials = Credentials.load()

    with {:ok, email} <- require_email(credentials),
         {:ok, token} <- require_token(credentials),
         {:ok, base_url} <- Config.server_url(),
         {:ok, customers} <- Client.list("/customers", base_url: base_url, token: token),
         {:ok, self} <- find_self(customers, email) do
      render_customer(self, opts)
    else
      {:error, :not_logged_in} -> Error.result(:not_logged_in)
      {:error, :no_server} -> Error.result(:no_server)
      {:error, :account_not_found} -> {:error, "account #{credentials.email} not found", 1}
      {:error, %ApiError{} = error} -> Error.result(error)
    end
  end

  defp auth_body(email, password, opts) do
    body = %{email: email, password: password}

    case Keyword.get(opts, :expires) do
      nil -> body
      expires_in -> Map.put(body, :expires_in, expires_in)
    end
  end

  defp render_token(token, response, opts) do
    if Keyword.get(opts, :json, false) do
      {:ok, Output.json(response)}
    else
      {:ok, "Login successful ✅\nCopy this access key, it won't be displayed again:\n#{token}"}
    end
  end

  # Best-effort revoke: derive the access-key id from the token and call DELETE.
  # Any failure (no server, expired token, network) is swallowed — the local
  # credentials are removed regardless, so the user is always logged out locally.
  defp revoke_remote(token) do
    with {:ok, id} <- Token.access_key_id(token),
         {:ok, base_url} <- Config.server_url() do
      Client.request(:delete, "/access_keys/#{id}", base_url: base_url, token: token)
    end
  end

  defp require_email(%Credentials{email: email}) when is_binary(email), do: {:ok, email}
  defp require_email(_credentials), do: {:error, :not_logged_in}

  defp require_token(%Credentials{token: token}) when is_binary(token), do: {:ok, token}
  defp require_token(_credentials), do: {:error, :not_logged_in}

  defp find_self(customers, email) do
    case Enum.find(customers, fn customer -> customer["email"] == email end) do
      nil -> {:error, :account_not_found}
      customer -> {:ok, customer}
    end
  end

  defp render_customer(customer, opts) do
    if Keyword.get(opts, :json, false) do
      {:ok, Output.json(customer)}
    else
      row = %{
        email: customer["email"],
        role_id: customer["role_id"],
        status: customer["status"]
      }

      {:ok, Output.table([row], [:email, :role_id, :status])}
    end
  end
end
