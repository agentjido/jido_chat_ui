defmodule JidoChatUI.Repo.Migrations.CreateBridges do
  use Ecto.Migration

  def change do
    create table(:bridges) do
      add :name, :string
      add :adapter, :string
      add :status, :string
      add :config, :map
      add :metadata, :map
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:bridges, [:user_id])
  end
end
