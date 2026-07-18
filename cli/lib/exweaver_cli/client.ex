defmodule ExweaverCli.Client do
  @moduledoc """
  Thin `Req`-based client over the REST API (rest_api.md).

  Every call returns a typed result: `{:ok, body}` for 2xx, or
  `{:error, %ExweaverCli.ApiError{}}` for everything else (server error
  responses, transport failures, and the local no-server case). The command
  layer decides how to render those; this module never prints.

  Options accepted by `request/3`:

    * `:base_url`     — server URL; defaults to `ExweaverCli.Config.server_url/0`
    * `:token`        — bearer token to send
    * `:json`         — request body, JSON-encoded
    * `:params`       — query-string params
    * `:req_options`  — extra options merged into the `Req` request (tests
      inject `plug: {Req.Test, …}` here to stub the HTTP layer)
  """

  alias ExweaverCli.ApiError
  alias ExweaverCli.Config

  # Every REST endpoint lives under this prefix (rest_api.md). The stored server
  # URL is bare (e.g. `https://flags.internal`); callers pass unprefixed paths
  # like `/auth/login` and the prefix is added here in one place.
  @api_prefix "/api/v1"

  @doc """
  Fetch every item from a paginated list endpoint, following `next_cursor`
  until the last page, and return the flattened `data`. Non-paginated bodies
  are returned as-is (wrapped in a list).
  """
  @spec list(String.t(), keyword()) :: {:ok, [term()]} | {:error, ApiError.t()}
  def list(path, opts \\ []) do
    collect(path, opts, [])
  end

  defp collect(path, opts, acc) do
    case request(:get, path, opts) do
      {:ok, %{"data" => data, "next_cursor" => cursor}} when is_list(data) ->
        next_page(path, opts, acc ++ data, cursor)

      {:ok, %{"data" => data}} when is_list(data) ->
        {:ok, acc ++ data}

      {:ok, other} ->
        {:ok, acc ++ List.wrap(other)}

      {:error, _} = error ->
        error
    end
  end

  defp next_page(path, opts, acc, cursor) when is_binary(cursor) and cursor != "" do
    params = opts |> Keyword.get(:params, %{}) |> Map.new() |> Map.put(:after, cursor)
    collect(path, Keyword.put(opts, :params, params), acc)
  end

  defp next_page(_path, _opts, acc, _cursor), do: {:ok, acc}

  @spec request(atom(), String.t(), keyword()) :: {:ok, term()} | {:error, ApiError.t()}
  def request(method, path, opts \\ []) do
    with {:ok, base_url} <- resolve_base_url(opts) do
      base_url
      |> build_request(opts)
      |> run(method, path, opts)
    end
  end

  defp resolve_base_url(opts) do
    case Keyword.get(opts, :base_url) do
      nil -> from_config()
      base_url -> {:ok, base_url}
    end
  end

  defp from_config do
    case Config.server_url() do
      {:ok, url} ->
        {:ok, url}

      {:error, :no_server} ->
        {:error,
         %ApiError{
           status: nil,
           code: "no_server",
           message: "no server configured — run `exweaver config set-server <url>`"
         }}
    end
  end

  defp build_request(base_url, opts) do
    # No automatic retries: a CLI surfaces server errors immediately rather than
    # hanging on backoff. Callers can override via `:req_options`.
    [base_url: base_url, retry: false]
    |> Keyword.merge(auth(opts))
    |> Keyword.merge(Keyword.get(opts, :req_options, []))
    |> Req.new()
  end

  defp auth(opts) do
    case Keyword.get(opts, :token) do
      nil -> []
      token -> [auth: {:bearer, token}]
    end
  end

  defp run(req, method, path, opts) do
    request_opts =
      [method: method, url: @api_prefix <> path]
      |> maybe_put(:json, Keyword.get(opts, :json))
      |> maybe_put(:params, Keyword.get(opts, :params))

    case Req.request(req, request_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, api_error(status, body)}

      {:error, exception} ->
        {:error,
         %ApiError{
           status: nil,
           code: "connection_error",
           message: "could not reach server: #{Exception.message(exception)}"
         }}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp api_error(status, %{"error" => %{"code" => code} = error}) when is_binary(code) do
    %ApiError{status: status, code: code, message: error["message"]}
  end

  defp api_error(status, _body) do
    %ApiError{
      status: status,
      code: "http_#{status}",
      message: "unexpected server response (#{status})"
    }
  end
end
