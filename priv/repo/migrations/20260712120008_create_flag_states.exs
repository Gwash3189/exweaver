defmodule Exweaver.Repo.Migrations.CreateFlagStates do
  use Ecto.Migration

  def change do
    create table(:flag_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :state, :string, null: false, default: "off"
      add :percentage, :integer
      add :flag_id, references(:flags, type: :binary_id, on_delete: :delete_all), null: false

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:flag_states, [:flag_id, :environment_id])
    create index(:flag_states, [:environment_id])
  end
end
