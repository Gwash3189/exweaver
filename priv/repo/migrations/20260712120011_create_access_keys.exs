defmodule Exweaver.Repo.Migrations.CreateAccessKeys do
  use Ecto.Migration

  def change do
    create table(:access_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :kind, :string, null: false
      add :hashed_value, :string, null: false
      add :expired_at, :utc_datetime
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing), null: false
      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all)
      add :environment_id, references(:environments, type: :binary_id, on_delete: :delete_all)
      add :role_id, references(:roles, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:access_keys, [:company_id])
    create index(:access_keys, [:customer_id])
    create index(:access_keys, [:environment_id])
  end
end
