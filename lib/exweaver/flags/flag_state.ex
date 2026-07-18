defmodule Exweaver.Flags.FlagState do
  @moduledoc "The on/off + percentage of one flag in one environment."

  use Exweaver.Schema
  import Ecto.Changeset

  alias Exweaver.Flags.{Environment, Flag}

  schema "flag_states" do
    field :state, Ecto.Enum, values: [:on, :off], default: :off
    field :percentage, :integer

    belongs_to :flag, Flag
    belongs_to :environment, Environment

    timestamps()
  end

  @doc false
  def changeset(flag_state, attrs) do
    flag_state
    |> cast(attrs, [:state, :percentage, :flag_id, :environment_id])
    |> validate_required([:state, :flag_id, :environment_id])
    |> validate_number(:percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint([:flag_id, :environment_id],
      name: :flag_states_flag_id_environment_id_index
    )
    |> foreign_key_constraint(:flag_id)
    |> foreign_key_constraint(:environment_id)
  end
end
