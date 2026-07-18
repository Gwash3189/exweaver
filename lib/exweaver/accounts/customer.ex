defmodule Exweaver.Accounts.Customer do
  @moduledoc """
  A team member of a company. A NULL `hashed_password` means
  pre-approved but not yet signed up.
  """

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.{Company, Role}
  alias Exweaver.Auth.AccessKey

  schema "customers" do
    field :email, :string
    field :hashed_password, :string

    belongs_to :company, Company
    belongs_to :role, Role
    has_many :access_keys, AccessKey

    timestamps()
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:email, :hashed_password, :company_id, :role_id])
    |> validate_required([:email, :company_id, :role_id])
    |> unique_constraint(:email)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:role_id)
  end
end
