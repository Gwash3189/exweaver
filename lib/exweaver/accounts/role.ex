defmodule Exweaver.Accounts.Role do
  @moduledoc "A named permission bundle. Global seed data (decisions.md D11)."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.{Customer, RolePermission}
  alias Exweaver.Auth.AccessKey

  schema "roles" do
    field :name, :string

    has_many :customers, Customer
    has_many :role_permissions, RolePermission
    has_many :access_keys, AccessKey

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
