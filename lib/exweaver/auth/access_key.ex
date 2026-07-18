defmodule Exweaver.Auth.AccessKey do
  @moduledoc """
  A bearer token: `personal` kind is a customer's CLI token, `sdk` kind is an
  environment-scoped evaluation key (database_diagram.md).
  """

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.{Company, Customer, Role}
  alias Exweaver.Flags.Environment

  schema "access_keys" do
    field :name, :string
    field :kind, Ecto.Enum, values: [:personal, :sdk]
    field :hashed_value, :string
    field :expired_at, :utc_datetime

    belongs_to :company, Company
    belongs_to :customer, Customer
    belongs_to :environment, Environment
    belongs_to :role, Role

    timestamps()
  end

  @doc false
  def changeset(access_key, attrs) do
    access_key
    |> cast(attrs, [
      :name,
      :kind,
      :hashed_value,
      :expired_at,
      :company_id,
      :customer_id,
      :environment_id,
      :role_id
    ])
    |> validate_required([:name, :kind, :hashed_value, :company_id])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:customer_id)
    |> foreign_key_constraint(:environment_id)
    |> foreign_key_constraint(:role_id)
    |> validate_kind_invariants()
  end

  # personal ⇒ customer_id set, environment_id/role_id nil (role is inherited
  # dynamically from the customer). sdk ⇒ environment_id + role_id (automated)
  # set, customer_id nil. See database_diagram.md access_key notes.
  defp validate_kind_invariants(changeset) do
    case get_field(changeset, :kind) do
      :personal ->
        changeset
        |> validate_required([:customer_id])
        |> validate_blank(:environment_id)
        |> validate_blank(:role_id)

      :sdk ->
        changeset
        |> validate_required([:environment_id, :role_id])
        |> validate_blank(:customer_id)

      _ ->
        changeset
    end
  end

  defp validate_blank(changeset, field) do
    if get_field(changeset, field) do
      add_error(changeset, field, "must be blank")
    else
      changeset
    end
  end
end
