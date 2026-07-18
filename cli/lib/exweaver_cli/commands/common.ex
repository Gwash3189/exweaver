defmodule ExweaverCli.Commands.Common do
  @moduledoc """
  Helpers shared by the management command groups (flags, environments,
  end-users): resolving the authenticated session, building request options,
  rendering a mutation's result, and guarding destructive actions.
  """

  alias ExweaverCli.{Config, Output, Prompt}

  @typedoc "The resolved server URL + personal token for management calls."
  @type session :: %{base_url: String.t(), token: String.t()}

  @doc "Resolve the server URL and personal token, or a precondition error."
  @spec session() :: {:ok, session()} | {:error, :no_server} | {:error, :not_logged_in}
  def session do
    with {:ok, base_url} <- Config.server_url(),
         {:ok, token} <- Config.token() do
      {:ok, %{base_url: base_url, token: token}}
    end
  end

  @doc "Build `ExweaverCli.Client` options for a session, plus any extra options."
  @spec opts(session(), keyword()) :: keyword()
  def opts(%{base_url: base_url, token: token}, extra \\ []) do
    [base_url: base_url, token: token] ++ extra
  end

  @doc """
  Render a successful mutation: a friendly one-line message by default, or the
  raw response object as JSON when `--json` is set.
  """
  @spec render(String.t(), term(), keyword()) :: {:ok, String.t()}
  def render(message, data, opts) do
    if Keyword.get(opts, :json, false) do
      {:ok, Output.json(data)}
    else
      {:ok, message}
    end
  end

  @doc """
  Render a list of resources: an aligned table of the given `columns` by
  default, or the raw JSON array when `--json` is set. Columns are atoms; the
  matching string-keyed fields are pulled from each item.
  """
  @spec render_list([map()], [atom()], keyword()) :: {:ok, String.t()}
  def render_list(items, columns, opts) do
    if Keyword.get(opts, :json, false) do
      {:ok, Output.json(items)}
    else
      rows = Enum.map(items, &row(&1, columns))
      {:ok, Output.table(rows, columns)}
    end
  end

  # Project a string-keyed API item down to just the requested (atom) columns.
  defp row(item, columns) do
    Map.new(columns, fn column -> {column, item[Atom.to_string(column)]} end)
  end

  @doc """
  Guard a destructive action. Returns `:ok` when `--yes` was passed or the user
  confirms at the prompt, `:aborted` otherwise.
  """
  @spec confirm(keyword(), String.t()) :: :ok | :aborted
  def confirm(opts, question) do
    if Keyword.get(opts, :yes, false) or Prompt.confirm?(question) do
      :ok
    else
      :aborted
    end
  end
end
