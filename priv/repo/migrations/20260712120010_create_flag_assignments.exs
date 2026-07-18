defmodule Exweaver.Repo.Migrations.CreateFlagAssignments do
  use Ecto.Migration

  def change do
    create table(:flag_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :state, :boolean, null: false
      add :flag_id, references(:flags, type: :binary_id, on_delete: :delete_all), null: false

      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :end_user_id, references(:end_users, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:flag_assignments, [:flag_id, :environment_id, :end_user_id])
    create index(:flag_assignments, [:environment_id])
    create index(:flag_assignments, [:end_user_id])
  end
end
