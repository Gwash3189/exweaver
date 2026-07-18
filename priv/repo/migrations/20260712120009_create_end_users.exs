defmodule Exweaver.Repo.Migrations.CreateEndUsers do
  use Ecto.Migration

  def change do
    create table(:end_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identifier, :string, null: false
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:end_users, [:company_id, :identifier])
  end
end
