defmodule Exweaver.Flags.FlagAssignment do
  @moduledoc "A per-end-user override of a flag in an environment."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Flags.{EndUser, Environment, Flag}

  schema "flag_assignments" do
    field :state, :boolean

    belongs_to :flag, Flag
    belongs_to :environment, Environment
    belongs_to :end_user, EndUser

    timestamps()
  end

  @doc false
  def changeset(flag_assignment, attrs) do
    flag_assignment
    |> cast(attrs, [:state, :flag_id, :environment_id, :end_user_id])
    |> validate_required([:state, :flag_id, :environment_id, :end_user_id])
    |> unique_constraint([:flag_id, :environment_id, :end_user_id],
      name: :flag_assignments_flag_id_environment_id_end_user_id_index
    )
    |> foreign_key_constraint(:flag_id)
    |> foreign_key_constraint(:environment_id)
    |> foreign_key_constraint(:end_user_id)
  end
end
