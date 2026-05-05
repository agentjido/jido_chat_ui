defmodule JidoChatUI.Repo.Migrations.CreateJidoMessagingTables do
  use Ecto.Migration

  def change do
    create table(:jido_messaging_rooms, primary_key: false) do
      add :id, :string, primary_key: true
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:jido_messaging_participants, primary_key: false) do
      add :id, :string, primary_key: true
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:jido_messaging_threads, primary_key: false) do
      add :id, :string, primary_key: true
      add :room_id, :string, null: false
      add :external_thread_id, :string
      add :root_message_id, :string
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jido_messaging_threads, [:room_id])
    create index(:jido_messaging_threads, [:room_id, :external_thread_id])
    create index(:jido_messaging_threads, [:room_id, :root_message_id])

    create table(:jido_messaging_messages, primary_key: false) do
      add :id, :string, primary_key: true
      add :room_id, :string, null: false
      add :thread_id, :string
      add :external_id, :string
      add :channel, :string
      add :bridge_id, :string
      add :message_inserted_at, :utc_datetime_usec
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jido_messaging_messages, [:room_id])
    create index(:jido_messaging_messages, [:thread_id])
    create index(:jido_messaging_messages, [:room_id, :message_inserted_at])
    create index(:jido_messaging_messages, [:channel, :bridge_id, :external_id])

    create table(:jido_messaging_room_bindings, primary_key: false) do
      add :id, :string, primary_key: true
      add :room_id, :string, null: false
      add :channel, :string, null: false
      add :bridge_id, :string, null: false
      add :external_room_id, :string, null: false
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jido_messaging_room_bindings, [:room_id])

    create unique_index(:jido_messaging_room_bindings, [
             :channel,
             :bridge_id,
             :external_room_id
           ])

    create table(:jido_messaging_participant_bindings, primary_key: false) do
      add :id, :string, primary_key: true
      add :participant_id, :string, null: false
      add :channel, :string, null: false
      add :external_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jido_messaging_participant_bindings, [:participant_id])
    create unique_index(:jido_messaging_participant_bindings, [:channel, :external_id])

    create table(:jido_messaging_onboarding_flows, primary_key: false) do
      add :onboarding_id, :string, primary_key: true
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:jido_messaging_bridge_configs, primary_key: false) do
      add :id, :string, primary_key: true
      add :adapter_module, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:jido_messaging_bridge_configs, [:enabled])
    create index(:jido_messaging_bridge_configs, [:adapter_module])

    create table(:jido_messaging_routing_policies, primary_key: false) do
      add :room_id, :string, primary_key: true
      add :data, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
