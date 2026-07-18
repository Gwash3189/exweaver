defmodule Exweaver.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :hashed_password, :string
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing), null: false
      add :role_id, references(:roles, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:customers, [:email])
    create index(:customers, [:company_id])
    create index(:customers, [:role_id])
  end
end
