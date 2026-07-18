defmodule Exweaver.Flags.Flag do
  @moduledoc """
  A feature flag definition (key, name, type). Exists once per company; its
  state varies per environment (glossary.md).
  """

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.Company
  alias Exweaver.Flags.{FlagAssignment, FlagState}

  schema "flags" do
    field :name, :string
    field :key, :string
    field :type, Ecto.Enum, values: [:boolean, :percentage]

    belongs_to :company, Company
    has_many :flag_states, FlagState
    has_many :flag_assignments, FlagAssignment

    timestamps()
  end

  @doc false
  def changeset(flag, attrs) do
    flag
    |> cast(attrs, [:name, :key, :type, :company_id])
    |> validate_required([:name, :key, :type, :company_id])
    |> unique_constraint([:company_id, :key], name: :flags_company_id_key_index)
    |> foreign_key_constraint(:company_id)
  end

  @doc "Only `name` is mutable after creation — `key` is immutable (decisions.md D12)."
  def update_changeset(flag, attrs) do
    flag
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
