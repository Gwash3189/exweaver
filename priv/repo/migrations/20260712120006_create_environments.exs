defmodule Exweaver.Repo.Migrations.CreateEnvironments do
  use Ecto.Migration

  def change do
    create table(:environments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :key, :string, null: false
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:environments, [:company_id, :key])
  end
end
