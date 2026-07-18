defmodule Exweaver.Evaluation do
  @moduledoc """
  The flag evaluation path (evaluation.md). Kept separate from `Exweaver.Flags`
  so the hot, read-only path stays small (conventions.md).
  """

  import Ecto.Query

  alias Exweaver.Flags.{EndUser, Environment, Flag, FlagAssignment, FlagState}
  alias Exweaver.Repo

  @doc "Evaluates every flag in the environment's company, keyed by flag key."
  def evaluate_all(%Environment{} = environment, identifier) do
    assignments = fetch_assignments(environment, identifier)

    from(f in Flag,
      join: fs in FlagState,
      on: fs.flag_id == f.id and fs.environment_id == ^environment.id,
      where: f.company_id == ^environment.company_id,
      select: {f, fs}
    )
    |> Repo.all()
    |> Map.new(fn {flag, flag_state} ->
      {flag.key, resolve(flag, flag_state, assignments, identifier)}
    end)
  end

  @doc "Evaluates a single flag by key. Returns `{:error, :not_found}` for an unknown key."
  def evaluate_one(%Environment{} = environment, flag_key, identifier) do
    case Repo.get_by(Flag, company_id: environment.company_id, key: flag_key) do
      nil ->
        {:error, :not_found}

      flag ->
        flag_state = Repo.get_by!(FlagState, flag_id: flag.id, environment_id: environment.id)
        assignments = fetch_assignments(environment, identifier)
        {:ok, resolve(flag, flag_state, assignments, identifier)}
    end
  end

  defp fetch_assignments(%Environment{}, nil), do: %{}

  defp fetch_assignments(%Environment{} = environment, identifier) do
    case Repo.get_by(EndUser, company_id: environment.company_id, identifier: identifier) do
      nil ->
        %{}

      end_user ->
        FlagAssignment
        |> where(environment_id: ^environment.id, end_user_id: ^end_user.id)
        |> Repo.all()
        |> Map.new(&{&1.flag_id, &1.state})
    end
  end

  defp resolve(%Flag{id: flag_id} = flag, flag_state, assignments, identifier) do
    case Map.fetch(assignments, flag_id) do
      {:ok, state} -> state
      :error -> resolve_state(flag, flag_state, identifier)
    end
  end

  defp resolve_state(_flag, %FlagState{state: :off}, _identifier), do: false
  defp resolve_state(%Flag{type: :boolean}, %FlagState{state: :on}, _identifier), do: true
  defp resolve_state(%Flag{type: :percentage}, %FlagState{state: :on}, nil), do: false

  defp resolve_state(
         %Flag{type: :percentage, key: key},
         %FlagState{state: :on} = flag_state,
         identifier
       ) do
    bucket(key, identifier) < (flag_state.percentage || 0)
  end

  # decisions.md D10 — environment is deliberately excluded from the hash.
  defp bucket(flag_key, identifier) do
    <<hash::unsigned-integer-size(256)>> = :crypto.hash(:sha256, flag_key <> ":" <> identifier)
    rem(hash, 100)
  end
end
