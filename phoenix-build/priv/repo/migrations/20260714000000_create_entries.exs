defmodule Fireside.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries) do
      add :name, :string, null: false
      add :message, :string, null: false
      timestamps()
    end
  end
end
