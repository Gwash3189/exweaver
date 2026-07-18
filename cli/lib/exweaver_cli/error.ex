defmodule ExweaverCli.Error do
  @moduledoc """
  Renders `ExweaverCli.ApiError`s into user-facing messages and exit codes
  (cli.md "Behavior conventions").
  """

  alias ExweaverCli.ApiError

  @doc """
  A human-readable, single-line message for an API error. `token_expired` gets
  the canonical "log in again" prompt from cli.md; `no_server` points at the
  config command; everything else falls back to the server-provided message.
  """
  @spec friendly_message(ApiError.t()) :: String.t()
  def friendly_message(%ApiError{code: "token_expired"}) do
    "token expired, run `exweaver login`"
  end

  def friendly_message(%ApiError{code: "no_server"}) do
    "no server configured — run `exweaver config set-server <url>`"
  end

  def friendly_message(%ApiError{message: message}) when is_binary(message) and message != "" do
    message
  end

  def friendly_message(%ApiError{code: code}), do: code

  @doc "Exit code for an API error. All runtime errors exit 1 (cli.md)."
  @spec exit_code(ApiError.t()) :: non_neg_integer()
  def exit_code(%ApiError{}), do: 1

  @doc """
  Maps an error into a command result `{:error, message, exit_code}` for the
  CLI dispatcher. Handles both `ApiError`s from the client and the atom errors
  `ExweaverCli.Config` returns for local preconditions.
  """
  @spec result(term()) :: {:error, String.t(), non_neg_integer()}
  def result(%ApiError{} = error), do: {:error, friendly_message(error), exit_code(error)}

  def result(:no_server) do
    {:error, "no server configured — run `exweaver config set-server <url>`", 1}
  end

  def result(:not_logged_in), do: {:error, "not logged in, run `exweaver login`", 1}

  def result({:not_found, kind, value}), do: {:error, "no #{kind} found: #{value}", 1}

  def result(:env_required), do: {:error, "the --env <env_key> option is required", 1}

  def result(:percentage_required) do
    {:error, "the --percentage <0-100> option is required", 1}
  end

  def result(:invalid_percentage), do: {:error, "--percentage must be between 0 and 100", 1}

  def result(:state_required), do: {:error, "the --state <on|off> option is required", 1}

  def result(:admin_email_required) do
    {:error, "the --admin-email <email> option is required", 1}
  end

  def result(:role_required), do: {:error, "the --role <role_name> option is required", 1}
end
