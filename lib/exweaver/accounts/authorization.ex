defmodule Exweaver.Accounts.Authorization do
  @moduledoc """
  The single home for the RBAC decision (decisions.md D28/D29).

  Answers two questions against the global role/permission seed grid:

    * `authorize/2` — does an actor's role grant a permission?
    * `require_admin/1` — is an actor an admin?

  `ExweaverWeb.Plugs.Authorize` is the sole *permission-by-method* gate and
  reaches this module through the `Exweaver.Accounts.authorize/2` facade. The
  *role-specific* rules that permission-by-method can't express (admin-only
  company creation and password reset, D24) call `require_admin/1` directly from
  the context function performing the privileged action.
  """

  import Ecto.Query, only: [from: 2]

  alias Exweaver.Accounts.{Customer, Permission, Role, RolePermission}
  alias Exweaver.Repo

  @permissions [:create, :read, :update, :delete]

  @doc "`:ok` when the actor's role grants `permission`, else `{:error, :unauthorized}`."
  def authorize(%Customer{role_id: role_id}, permission) when permission in @permissions do
    permission_name = Atom.to_string(permission)

    query =
      from rp in RolePermission,
        join: p in Permission,
        on: p.id == rp.permission_id,
        where: rp.role_id == ^role_id and p.name == ^permission_name

    if Repo.exists?(query), do: :ok, else: {:error, :unauthorized}
  end

  @doc "`:ok` when the actor holds the admin role, else `{:error, :unauthorized}`."
  def require_admin(%Customer{role_id: role_id}) do
    if Repo.exists?(from r in Role, where: r.id == ^role_id and r.name == "admin") do
      :ok
    else
      {:error, :unauthorized}
    end
  end
end
