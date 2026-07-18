defmodule Exweaver.Accounts do
  @moduledoc """
  Tenancy, team members, password set/verify, and RBAC checks (conventions.md).
  """

  import Ecto.Query, only: [from: 2]

  alias Exweaver.Accounts.{Authorization, Company, Customer, Role}
  alias Exweaver.Flags
  alias Exweaver.Pagination
  alias Exweaver.Repo

  @doc """
  Actor-driven company creation. Requires the actor's role to be `admin`:
  permission-by-method can't express this, since `developer` also holds `:create`.
  The actor-less `create_company/2` remains for first-boot bootstrap .
  """
  def create_company(%Customer{} = actor, name, admin_email) do
    with :ok <- Authorization.require_admin(actor) do
      create_company(name, admin_email)
    end
  end

  @doc """
  Creates a company, its pre-approved admin customer, and its default
  environments in one transaction - all commit or none do. Used by
  first-boot bootstrap and by `create_company/3`.
  """
  def create_company(name, admin_email) do
    Repo.transaction(fn ->
      with {:ok, company} <- insert_company(name),
           admin_role <- Repo.get_by!(Role, name: "admin"),
           {:ok, admin} <- insert_customer(company.id, admin_role.id, admin_email),
           {:ok, _environments} <- Flags.seed_environments(company) do
        %{company: company, admin: admin}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Invites (pre-approves) a customer in the actor's company. Method-permission
  RBAC (`:create`) is enforced upstream by the `Authorize` plug (D28/D29), so
  this only scopes to the actor's company.
  """
  def invite_customer(%Customer{} = actor, email, role_id) do
    insert_customer(actor.company_id, role_id, email)
  end

  def set_password(%Customer{hashed_password: nil} = customer, password) do
    customer
    |> Customer.changeset(%{hashed_password: Bcrypt.hash_pwd_salt(password)})
    |> Repo.update()
  end

  def set_password(%Customer{}, _password), do: {:error, :password_already_set}

  def verify_password(%Customer{hashed_password: nil}, _password) do
    Bcrypt.no_user_verify()
    false
  end

  def verify_password(%Customer{hashed_password: hash}, password) do
    Bcrypt.verify_pass(password, hash)
  end

  @doc "rest_api.md: admin-only (mirrors the D24 admin-only rule for create_company/3)."
  def reset_customer(%Customer{} = actor, id) do
    with :ok <- Authorization.require_admin(actor),
         {:ok, customer} <- fetch_customer(actor, id),
         {:ok, customer} <-
           customer |> Customer.changeset(%{hashed_password: nil}) |> Repo.update() do
      Exweaver.Auth.revoke_all_for_customer(customer)
      {:ok, customer}
    end
  end

  @doc "Looks up a customer by email, globally (email is unique across companies)."
  def get_customer_by_email(email) do
    Repo.get_by(Customer, email: email)
  end

  @doc """
  Loads a customer by id with `:role` and `:company` preloaded — the actor shape
  `BearerAuth` and the `Authorize` plug need. Returns `nil` if absent (so a token
  whose customer is gone resolves to a clean 401 rather than a raise — K8).
  """
  def get_customer(id) do
    case Repo.get(Customer, id) do
      nil -> nil
      customer -> Repo.preload(customer, [:role, :company])
    end
  end

  def list_customers(%Customer{company_id: company_id}) do
    Repo.all(from c in Customer, where: c.company_id == ^company_id)
  end

  def list_customers(%Customer{company_id: company_id}, opts) do
    from(c in Customer, where: c.company_id == ^company_id)
    |> Pagination.paginate(opts)
  end

  @doc "Roles are global seed data (decisions.md D11), not scoped to a company."
  def list_roles(opts \\ []) do
    Pagination.paginate(Role, opts)
  end

  def update_customer(%Customer{} = actor, id, attrs) do
    with {:ok, customer} <- fetch_customer(actor, id) do
      customer
      |> Customer.changeset(Map.take(attrs, [:email, :role_id]))
      |> Repo.update()
    end
  end

  def delete_customer(%Customer{} = actor, id) do
    with {:ok, customer} <- fetch_customer(actor, id) do
      Repo.delete(customer)
    end
  end

  @doc """
  The context facade for the permission-by-method RBAC check the `Authorize`
  plug performs. Delegates to `Exweaver.Accounts.Authorization`, the single home
  for the RBAC decision (D28/D29).
  """
  defdelegate authorize(actor, permission), to: Authorization

  defp insert_company(name) do
    %Company{} |> Company.changeset(%{name: name}) |> Repo.insert()
  end

  defp insert_customer(company_id, role_id, email) do
    %Customer{}
    |> Customer.changeset(%{email: email, company_id: company_id, role_id: role_id})
    |> Repo.insert()
  end

  defp fetch_customer(%Customer{company_id: company_id}, id) do
    with true <- Exweaver.UUIDv7.valid?(id),
         customer when not is_nil(customer) <-
           Repo.get_by(Customer, id: id, company_id: company_id) do
      {:ok, customer}
    else
      _ -> {:error, :not_found}
    end
  end
end
