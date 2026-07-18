defmodule Exweaver.Flags.EndUser do
  @moduledoc "The customer's customer, identified only by an opaque identifier (glossary.md)."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Accounts.Company
  alias Exweaver.Flags.FlagAssignment

  schema "end_users" do
    field :identifier, :string

    belongs_to :company, Company
    has_many :flag_assignments, FlagAssignment

    timestamps()
  end

  @doc false
  def changeset(end_user, attrs) do
    end_user
    |> cast(attrs, [:identifier, :company_id])
    |> validate_required([:identifier, :company_id])
    |> unique_constraint([:company_id, :identifier], name: :end_users_company_id_identifier_index)
    |> foreign_key_constraint(:company_id)
  end
end
