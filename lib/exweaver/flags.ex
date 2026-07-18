defmodule Exweaver.Flags do
  @moduledoc """
  Flag, environment, and end_user CRUD — all company-scoped (conventions.md).
  """

  import Ecto.Query

  alias Exweaver.Accounts.Company
  alias Exweaver.Flags.{EndUser, Environment, Flag, FlagAssignment, FlagState}
  alias Exweaver.Pagination
  alias Exweaver.Repo
  alias Exweaver.UUIDv7

  ## Environments

  @default_environments [
    %{name: "Production", key: "production"},
    %{name: "Development", key: "development"}
  ]

  @doc """
  Seeds the two default environments for a company (decisions.md D5). Atomic (one
  transaction) and idempotent (get-or-create per key) so it is safe to re-run —
  conventions.md lists default environments among idempotent seed data.
  """
  def seed_environments(%Company{} = company) do
    Repo.transaction(fn ->
      Enum.map(@default_environments, &get_or_create_environment!(company, &1))
    end)
  end

  defp get_or_create_environment!(%Company{} = company, %{key: key} = attrs) do
    case Repo.get_by(Environment, company_id: company.id, key: key) do
      nil ->
        case create_environment_row(company, attrs) do
          {:ok, environment} -> environment
          {:error, changeset} -> Repo.rollback(changeset)
        end

      environment ->
        environment
    end
  end

  def list_environments(%Company{} = company) do
    Environment
    |> where(company_id: ^company.id)
    |> Repo.all()
  end

  def list_environments(%Company{} = company, opts) do
    Environment
    |> where(company_id: ^company.id)
    |> Pagination.paginate(opts)
  end

  @doc """
  Loads an environment by id (not company-scoped) with `:company` preloaded — the
  actor shape `BearerAuth` needs when resolving an sdk key. Returns `nil` if absent
  (so a token whose environment is gone resolves to a clean 401 — K8).
  """
  def get_environment(id) do
    case Repo.get(Environment, id) do
      nil -> nil
      environment -> Repo.preload(environment, :company)
    end
  end

  def get_environment(%Company{} = company, id) do
    if UUIDv7.valid?(id), do: Repo.get_by(Environment, id: id, company_id: company.id)
  end

  @doc "Creates an environment and an off flag_state for every existing flag (decisions.md D5)."
  def create_environment(%Company{} = company, attrs) do
    Repo.transaction(fn ->
      case create_environment_row(company, attrs) do
        {:ok, environment} -> environment
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Inserts the environment row and its off flag_states without opening its own
  # transaction, so callers (create_environment/2, seed_environments/1) control
  # the transaction boundary.
  defp create_environment_row(%Company{} = company, attrs) do
    changeset = Environment.changeset(%Environment{}, Map.put(attrs, :company_id, company.id))

    case Repo.insert(changeset) do
      {:ok, environment} ->
        Enum.each(list_flags(company), &create_flag_state!(&1, environment))
        {:ok, environment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_environment(%Environment{} = environment, attrs) do
    environment
    |> Environment.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Rejects deleting a company's last environment."
  def delete_environment(%Company{} = company, %Environment{} = environment) do
    if last_environment?(company) do
      {:error, :last_environment}
    else
      Repo.delete(environment)
    end
  end

  defp last_environment?(%Company{} = company) do
    Environment
    |> where(company_id: ^company.id)
    |> Repo.aggregate(:count) <= 1
  end

  ## Flags

  def list_flags(%Company{} = company) do
    Flag
    |> where(company_id: ^company.id)
    |> Repo.all()
  end

  @doc "Preloads each flag's flag_states + environment (rest_api.md: list includes state per environment)."
  def list_flags(%Company{} = company, opts) do
    {flags, next_cursor} =
      Flag
      |> where(company_id: ^company.id)
      |> Pagination.paginate(opts)

    {Repo.preload(flags, flag_states: :environment), next_cursor}
  end

  @doc "Preloads flag_states + environment (rest_api.md: list includes state per environment)."
  def get_flag(%Company{} = company, id) do
    if UUIDv7.valid?(id) do
      Flag
      |> Repo.get_by(id: id, company_id: company.id)
      |> Repo.preload(flag_states: :environment)
    end
  end

  @doc "Creates a flag and an off flag_state for every existing environment (decisions.md D5)."
  def create_flag(%Company{} = company, attrs) do
    Repo.transaction(fn ->
      changeset = Flag.changeset(%Flag{}, Map.put(attrs, :company_id, company.id))

      case Repo.insert(changeset) do
        {:ok, flag} ->
          Enum.each(list_environments(company), &create_flag_state!(flag, &1))
          Repo.preload(flag, flag_states: :environment)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def update_flag(%Flag{} = flag, attrs) do
    flag
    |> Flag.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_flag(%Flag{} = flag) do
    Repo.delete(flag)
  end

  defp create_flag_state!(%Flag{} = flag, %Environment{} = environment) do
    Repo.insert!(
      FlagState.changeset(%FlagState{}, %{
        state: :off,
        flag_id: flag.id,
        environment_id: environment.id
      })
    )
  end

  ## Flag state

  def get_state(%Flag{} = flag, %Environment{} = environment) do
    Repo.get_by(FlagState, flag_id: flag.id, environment_id: environment.id)
  end

  @doc "Percentage is only accepted for percentage-type flags."
  def put_state(%Flag{} = flag, %Environment{} = environment, attrs) do
    flag_state = Repo.get_by!(FlagState, flag_id: flag.id, environment_id: environment.id)

    flag_state
    |> FlagState.changeset(attrs)
    |> validate_percentage_for_flag_type(flag)
    |> Repo.update()
  end

  defp validate_percentage_for_flag_type(changeset, %Flag{type: :percentage}), do: changeset

  defp validate_percentage_for_flag_type(changeset, %Flag{type: :boolean}) do
    case Ecto.Changeset.get_change(changeset, :percentage) do
      nil ->
        changeset

      _ ->
        Ecto.Changeset.add_error(
          changeset,
          :percentage,
          "is only valid for percentage-type flags"
        )
    end
  end

  ## Flag assignments

  def list_assignments(%Flag{} = flag, %Environment{} = environment) do
    FlagAssignment
    |> where(flag_id: ^flag.id, environment_id: ^environment.id)
    |> Repo.all()
  end

  def list_assignments(%Flag{} = flag, %Environment{} = environment, opts) do
    FlagAssignment
    |> where(flag_id: ^flag.id, environment_id: ^environment.id)
    |> Pagination.paginate(opts)
  end

  def get_assignment(%Flag{} = flag, %Environment{} = environment, %EndUser{} = end_user) do
    Repo.get_by(FlagAssignment,
      flag_id: flag.id,
      environment_id: environment.id,
      end_user_id: end_user.id
    )
  end

  def upsert_assignment(
        %Flag{} = flag,
        %Environment{} = environment,
        %EndUser{} = end_user,
        state
      ) do
    case Repo.get_by(FlagAssignment,
           flag_id: flag.id,
           environment_id: environment.id,
           end_user_id: end_user.id
         ) do
      nil ->
        Repo.insert(
          FlagAssignment.changeset(%FlagAssignment{}, %{
            state: state,
            flag_id: flag.id,
            environment_id: environment.id,
            end_user_id: end_user.id
          })
        )

      assignment ->
        assignment
        |> FlagAssignment.changeset(%{state: state})
        |> Repo.update()
    end
  end

  def delete_assignment(%FlagAssignment{} = assignment) do
    Repo.delete(assignment)
  end

  ## End users

  def list_end_users(%Company{} = company) do
    EndUser
    |> where(company_id: ^company.id)
    |> Repo.all()
  end

  @doc "Supports an `:identifier` exact-match filter (rest_api.md `?identifier=`) plus pagination."
  def list_end_users(%Company{} = company, opts) do
    {identifier, opts} = Keyword.pop(opts, :identifier)

    EndUser
    |> where(company_id: ^company.id)
    |> maybe_filter_identifier(identifier)
    |> Pagination.paginate(opts)
  end

  defp maybe_filter_identifier(query, nil), do: query
  defp maybe_filter_identifier(query, identifier), do: where(query, identifier: ^identifier)

  def get_end_user(%Company{} = company, id) do
    if UUIDv7.valid?(id), do: Repo.get_by(EndUser, id: id, company_id: company.id)
  end

  @doc "Not auto-created by evaluation — end_users are explicitly created here (decisions.md D13)."
  def create_end_user(%Company{} = company, attrs) do
    %EndUser{}
    |> EndUser.changeset(Map.put(attrs, :company_id, company.id))
    |> Repo.insert()
  end

  def delete_end_user(%EndUser{} = end_user) do
    Repo.delete(end_user)
  end
end
