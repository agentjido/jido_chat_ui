defmodule JidoChatUI.Repo.Migrations.CreateRoomBridges do
  use Ecto.Migration

  def change do
    create table(:room_bridges) do
      add :external_room_id, :string
      add :external_thread_id, :string
      add :status, :string
      add :metadata, :map
      add :room_id, references(:rooms, on_delete: :nothing)
      add :bridge_id, references(:bridges, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:room_bridges, [:user_id])

    create index(:room_bridges, [:room_id])
    create index(:room_bridges, [:bridge_id])
  end
end
