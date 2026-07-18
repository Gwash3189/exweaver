defmodule ExweaverCli.Commands.Flags do
  @moduledoc """
  Flag commands (cli.md): `list`, `create`, `delete`, `on`, `off`, `rollout`,
  `assign`, `unassign`. Flag/environment keys and end-user identifiers are
  resolved to ids via `ExweaverCli.Resolver` so users never type UUIDs.
  """

  alias ExweaverCli.{Client, Error, Resolver}
  alias ExweaverCli.Commands.Common

  @doc "List all flags."
  @spec list(keyword()) :: {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def list(opts) do
    with {:ok, session} <- Common.session(),
         {:ok, flags} <- Client.list("/flags", Common.opts(session)) do
      Common.render_list(flags, [:key, :name, :type], opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Create a flag. `--name` defaults to the key; `--type` defaults to boolean."
  @spec create(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def create(key, opts) do
    attrs = %{
      key: key,
      name: Keyword.get(opts, :name, key),
      type: Keyword.get(opts, :type, "boolean")
    }

    with {:ok, session} <- Common.session(),
         {:ok, flag} <- Client.request(:post, "/flags", Common.opts(session, json: attrs)) do
      Common.render("Created flag #{key}", flag, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Delete a flag (confirms unless `--yes`)."
  @spec delete(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def delete(key, opts) do
    with {:ok, session} <- Common.session(),
         {:ok, flag_id} <- Resolver.flag_id(session, key),
         :ok <- Common.confirm(opts, "Delete flag #{key}?"),
         {:ok, response} <- Client.request(:delete, "/flags/#{flag_id}", Common.opts(session)) do
      Common.render("Deleted flag #{key}", response, opts)
    else
      :aborted -> {:ok, "Aborted."}
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Turn a flag on or off in an environment (`--env`)."
  @spec set_state(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def set_state(key, state, opts) do
    with {:ok, env_key} <- require_env(opts),
         {:ok, session} <- Common.session(),
         {:ok, flag_id} <- Resolver.flag_id(session, key),
         {:ok, env_id} <- Resolver.environment_id(session, env_key),
         {:ok, response} <- put_state(session, flag_id, env_id, %{state: state}) do
      Common.render("Set flag #{key} to #{state} in #{env_key}", response, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Set a percentage rollout for a flag in an environment (`--env`, `--percentage`)."
  @spec rollout(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def rollout(key, opts) do
    with {:ok, percentage} <- require_percentage(opts),
         {:ok, env_key} <- require_env(opts),
         {:ok, session} <- Common.session(),
         {:ok, flag_id} <- Resolver.flag_id(session, key),
         {:ok, env_id} <- Resolver.environment_id(session, env_key),
         {:ok, response} <-
           put_state(session, flag_id, env_id, %{state: "on", percentage: percentage}) do
      Common.render("Rolled out flag #{key} to #{percentage}% in #{env_key}", response, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Assign a per-user override (`--env`, `--state on|off`); creates the end_user if new."
  @spec assign(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def assign(key, identifier, opts) do
    with {:ok, state} <- require_state(opts),
         {:ok, env_key} <- require_env(opts),
         {:ok, session} <- Common.session(),
         {:ok, flag_id} <- Resolver.flag_id(session, key),
         {:ok, env_id} <- Resolver.environment_id(session, env_key),
         {:ok, end_user_id} <- Resolver.resolve_or_create_end_user_id(session, identifier),
         {:ok, response} <-
           Client.request(
             :put,
             assignment_path(flag_id, env_id, end_user_id),
             Common.opts(session, json: %{state: state})
           ) do
      label = if state, do: "on", else: "off"

      Common.render(
        "Assigned flag #{key}=#{label} to #{identifier} in #{env_key}",
        response,
        opts
      )
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  @doc "Remove a per-user override (`--env`)."
  @spec unassign(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t(), non_neg_integer()}
  def unassign(key, identifier, opts) do
    with {:ok, env_key} <- require_env(opts),
         {:ok, session} <- Common.session(),
         {:ok, flag_id} <- Resolver.flag_id(session, key),
         {:ok, env_id} <- Resolver.environment_id(session, env_key),
         {:ok, end_user_id} <- Resolver.end_user_id(session, identifier),
         {:ok, response} <-
           Client.request(
             :delete,
             assignment_path(flag_id, env_id, end_user_id),
             Common.opts(session)
           ) do
      Common.render("Unassigned flag #{key} from #{identifier} in #{env_key}", response, opts)
    else
      {:error, reason} -> Error.result(reason)
    end
  end

  defp put_state(session, flag_id, env_id, body) do
    Client.request(
      :put,
      "/flags/#{flag_id}/environments/#{env_id}/state",
      Common.opts(session, json: body)
    )
  end

  defp assignment_path(flag_id, env_id, end_user_id) do
    "/flags/#{flag_id}/environments/#{env_id}/assignments/#{end_user_id}"
  end

  defp require_env(opts) do
    case Keyword.get(opts, :env) do
      nil -> {:error, :env_required}
      env_key -> {:ok, env_key}
    end
  end

  defp require_percentage(opts) do
    case Keyword.get(opts, :percentage) do
      nil -> {:error, :percentage_required}
      percentage when percentage in 0..100 -> {:ok, percentage}
      _out_of_range -> {:error, :invalid_percentage}
    end
  end

  defp require_state(opts) do
    case Keyword.get(opts, :state) do
      "on" -> {:ok, true}
      "off" -> {:ok, false}
      _missing_or_invalid -> {:error, :state_required}
    end
  end
end
