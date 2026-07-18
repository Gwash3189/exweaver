defmodule Exweaver.Accounts.Permission do
  @moduledoc "An atomic capability (create/read/update/delete). Global seed data."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.RolePermission

  schema "permissions" do
    field :name, :string

    has_many :role_permissions, RolePermission

    timestamps()
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
