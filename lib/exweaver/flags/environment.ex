defmodule Exweaver.Flags.Environment do
  @moduledoc "A deployment context (e.g. production, development) owned by a company."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.Company
  alias Exweaver.Auth.AccessKey
  alias Exweaver.Flags.{FlagAssignment, FlagState}

  schema "environments" do
    field :name, :string
    field :key, :string

    belongs_to :company, Company
    has_many :flag_states, FlagState
    has_many :flag_assignments, FlagAssignment
    has_many :access_keys, AccessKey

    timestamps()
  end

  @doc false
  def changeset(environment, attrs) do
    environment
    |> cast(attrs, [:name, :key, :company_id])
    |> validate_required([:name, :key, :company_id])
    |> unique_constraint([:company_id, :key], name: :environments_company_id_key_index)
    |> foreign_key_constraint(:company_id)
  end

  @doc "Only `name` is mutable after creation — `key` is immutable, like flag keys."
  def update_changeset(environment, attrs) do
    environment
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
