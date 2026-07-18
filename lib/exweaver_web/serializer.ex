defmodule ExweaverWeb.Serializer do
  @moduledoc """
  The single home for the JSON response contract (conventions.md).

  Every management endpoint renders resources as flat JSON objects and lists as
  `%{data: [...], next_cursor: ...}`. Two rules that used to be re-implemented in
  every controller now live here once:

    * timestamps are UTC ISO8601 (`iso8601/1`, nil-safe — so a nil `expired_at`
      renders as `null` instead of raising);
    * list responses share one `page/3` envelope.

  A resource's shape lives beside the others here, so a global change to the
  response contract is one edit rather than ten.
  """

  alias Exweaver.Accounts.{Company, Customer, Role}
  alias Exweaver.Auth.AccessKey
  alias Exweaver.Flags.{EndUser, Environment, Flag, FlagAssignment, FlagState}

  @doc "Renders a UTC ISO8601 timestamp, or `nil` for an absent one."
  def iso8601(nil), do: nil
  def iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  @doc "Wraps a page of items in the shared `%{data:, next_cursor:}` list envelope."
  def page(items, next_cursor, render_fun) when is_function(render_fun, 1) do
    %{data: Enum.map(items, render_fun), next_cursor: next_cursor}
  end

  def flag(%Flag{} = flag) do
    %{
      id: flag.id,
      name: flag.name,
      key: flag.key,
      type: flag.type,
      company_id: flag.company_id,
      states: Enum.map(flag.flag_states, &flag_state_summary/1),
      inserted_at: iso8601(flag.inserted_at),
      updated_at: iso8601(flag.updated_at)
    }
  end

  defp flag_state_summary(%FlagState{} = flag_state) do
    %{
      environment_id: flag_state.environment_id,
      environment_key: flag_state.environment.key,
      state: flag_state.state,
      percentage: flag_state.percentage
    }
  end

  def flag_state(%FlagState{} = flag_state) do
    %{
      id: flag_state.id,
      flag_id: flag_state.flag_id,
      environment_id: flag_state.environment_id,
      state: flag_state.state,
      percentage: flag_state.percentage,
      inserted_at: iso8601(flag_state.inserted_at),
      updated_at: iso8601(flag_state.updated_at)
    }
  end

  def assignment(%FlagAssignment{} = assignment) do
    %{
      id: assignment.id,
      flag_id: assignment.flag_id,
      environment_id: assignment.environment_id,
      end_user_id: assignment.end_user_id,
      state: assignment.state,
      inserted_at: iso8601(assignment.inserted_at),
      updated_at: iso8601(assignment.updated_at)
    }
  end

  def environment(%Environment{} = environment) do
    %{
      id: environment.id,
      name: environment.name,
      key: environment.key,
      company_id: environment.company_id,
      inserted_at: iso8601(environment.inserted_at),
      updated_at: iso8601(environment.updated_at)
    }
  end

  def end_user(%EndUser{} = end_user) do
    %{
      id: end_user.id,
      identifier: end_user.identifier,
      company_id: end_user.company_id,
      inserted_at: iso8601(end_user.inserted_at),
      updated_at: iso8601(end_user.updated_at)
    }
  end

  def customer(%Customer{} = customer) do
    %{
      id: customer.id,
      email: customer.email,
      role_id: customer.role_id,
      company_id: customer.company_id,
      status: if(customer.hashed_password, do: "active", else: "pending"),
      inserted_at: iso8601(customer.inserted_at),
      updated_at: iso8601(customer.updated_at)
    }
  end

  @doc "The one-time plaintext `token` is only present on the creation response."
  def access_key(%AccessKey{} = access_key, token \\ nil) do
    %{
      id: access_key.id,
      name: access_key.name,
      kind: access_key.kind,
      company_id: access_key.company_id,
      customer_id: access_key.customer_id,
      environment_id: access_key.environment_id,
      expired_at: iso8601(access_key.expired_at),
      token: token,
      inserted_at: iso8601(access_key.inserted_at),
      updated_at: iso8601(access_key.updated_at)
    }
  end

  @doc "Companies are create-only; the response echoes the pre-approved admin's email."
  def company(%Company{} = company, %Customer{} = admin) do
    %{
      id: company.id,
      name: company.name,
      admin_email: admin.email,
      inserted_at: iso8601(company.inserted_at),
      updated_at: iso8601(company.updated_at)
    }
  end

  def role(%Role{} = role) do
    %{
      id: role.id,
      name: role.name,
      inserted_at: iso8601(role.inserted_at),
      updated_at: iso8601(role.updated_at)
    }
  end
end
