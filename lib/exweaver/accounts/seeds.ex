defmodule Exweaver.Accounts.Seeds do
  @moduledoc """
  Idempotent global seed data: roles, permissions, and the role/permission
  grid (database_diagram.md). Safe to run on every deploy.
  """

  alias Exweaver.Accounts.{Permission, Role, RolePermission}
  alias Exweaver.Repo

  @roles ~w(developer admin read-only automated)
  @permissions ~w(create read update delete)

  @grid %{
    "admin" => @permissions,
    "developer" => @permissions,
    "read-only" => ~w(read),
    "automated" => ~w(read)
  }

  def run do
    roles = Map.new(@roles, &{&1, upsert_role(&1)})
    permissions = Map.new(@permissions, &{&1, upsert_permission(&1)})

    for {role_name, permission_names} <- @grid,
        permission_name <- permission_names do
      upsert_role_permission(roles[role_name].id, permissions[permission_name].id)
    end

    :ok
  end

  defp upsert_role(name) do
    Repo.get_by(Role, name: name) || Repo.insert!(Role.changeset(%Role{}, %{name: name}))
  end

  defp upsert_permission(name) do
    Repo.get_by(Permission, name: name) ||
      Repo.insert!(Permission.changeset(%Permission{}, %{name: name}))
  end

  defp upsert_role_permission(role_id, permission_id) do
    Repo.get_by(RolePermission, role_id: role_id, permission_id: permission_id) ||
      Repo.insert!(
        RolePermission.changeset(%RolePermission{}, %{
          role_id: role_id,
          permission_id: permission_id
        })
      )
  end
end
