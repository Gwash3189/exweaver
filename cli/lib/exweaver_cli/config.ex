defmodule ExweaverCli.Config do
  @moduledoc """
  Resolves the server URL and personal token the client needs.

  The server URL comes from `$EXWEAVER_SERVER` when set, otherwise from the
  stored credentials (`exweaver config set-server …`). The env var wins so an
  operator can point a single invocation at a different server without
  rewriting the credentials file.
  """

  alias ExweaverCli.Credentials

  @doc """
  The configured server URL: `$EXWEAVER_SERVER` first, then the stored value.
  """
  @spec server_url() :: {:ok, String.t()} | {:error, :no_server}
  def server_url do
    case env_server() || Credentials.load().server do
      nil -> {:error, :no_server}
      url -> {:ok, url}
    end
  end

  @doc """
  Validate and persist the server URL to the credentials file. The URL must
  have an `http`/`https` scheme and a host; a trailing slash is stripped.
  """
  @spec set_server(String.t()) :: {:ok, String.t()} | {:error, :invalid_server}
  def set_server(url) when is_binary(url) do
    case normalize(url) do
      {:ok, normalized} ->
        {:ok, _} = Credentials.put(server: normalized)
        {:ok, normalized}

      :error ->
        {:error, :invalid_server}
    end
  end

  @doc "The stored personal token, or an error when the user is not logged in."
  @spec token() :: {:ok, String.t()} | {:error, :not_logged_in}
  def token do
    case Credentials.load().token do
      nil -> {:error, :not_logged_in}
      token -> {:ok, token}
    end
  end

  defp env_server do
    case System.get_env("EXWEAVER_SERVER") do
      nil -> nil
      "" -> nil
      value -> String.trim_trailing(value, "/")
    end
  end

  defp normalize(url) do
    trimmed = url |> String.trim() |> String.trim_trailing("/")

    case URI.parse(trimmed) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        {:ok, trimmed}

      _ ->
        :error
    end
  end
end
