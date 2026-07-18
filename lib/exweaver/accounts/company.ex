defmodule Exweaver.Accounts.Company do
  @moduledoc "A tenant. Everything else is scoped to a company (database_diagram.md)."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.Customer
  alias Exweaver.Auth.AccessKey
  alias Exweaver.Flags.{EndUser, Environment, Flag}

  schema "companies" do
    field :name, :string

    has_many :customers, Customer
    has_many :environments, Environment
    has_many :flags, Flag
    has_many :end_users, EndUser
    has_many :access_keys, AccessKey

    timestamps()
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
