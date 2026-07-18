defmodule Exweaver.Bootstrap do
  @moduledoc """
  Runs once at every startup, after migrations. Seeds the global RBAC grid
  (`Accounts.Seeds`, idempotent — conventions.md lists it among seed data safe to
  run on every deploy; nothing previously called it on boot). Then, first-boot
  bootstrap (decisions.md D18): if `EXWEAVER_ADMIN_EMAIL` is set and no customers
  exist yet, creates a company (with default environments) and a pre-approved
  admin customer. Idempotent — a populated database is left untouched.
  """

  alias Exweaver.{Accounts, Repo}
  alias Exweaver.Accounts.{Customer, Seeds}

  def run do
    Seeds.run()
    maybe_create_admin(System.get_env("EXWEAVER_ADMIN_EMAIL"))
    :ok
  end

  defp maybe_create_admin(admin_email) when admin_email in [nil, ""], do: :ok

  defp maybe_create_admin(admin_email) do
    if Repo.aggregate(Customer, :count) == 0 do
      # create_company/2 seeds the default environments in the same transaction.
      {:ok, _created} = Accounts.create_company("Default", admin_email)
    end

    :ok
  end

  @doc false
  def child_spec(_opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :temporary}
  end

  @doc false
  def start_link do
    run()
    :ignore
  end
end
