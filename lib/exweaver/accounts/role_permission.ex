defmodule Exweaver.Accounts.RolePermission do
  @moduledoc "Join table granting a permission to a role."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.{Permission, Role}

  schema "role_permissions" do
    belongs_to :role, Role
    belongs_to :permission, Permission

    timestamps()
  end

  @doc false
  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, [:role_id, :permission_id])
    |> validate_required([:role_id, :permission_id])
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:permission_id)
    |> unique_constraint([:role_id, :permission_id])
  end
end
