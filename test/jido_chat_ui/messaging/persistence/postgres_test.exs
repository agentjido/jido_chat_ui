defmodule JidoChatUI.Messaging.Persistence.PostgresTest do
  use JidoChatUI.DataCase, async: false

  alias Jido.Chat.Room
  alias Jido.Messaging.{BridgeConfig, Message}
  alias JidoChatUI.Messaging.Persistence.Postgres

  setup do
    {:ok, state} = Postgres.init(repo: Repo)
    %{state: state}
  end

  test "persists rooms and messages with external lookup indexes", %{state: state} do
    room = Room.new(%{id: "room-1", type: :group, name: "Integration room"})

    message =
      Message.new(%{
        room_id: room.id,
        sender_id: "user@example.com",
        role: :user,
        content: [%{type: :text, text: "hello from postgres"}],
        external_id: "ext-1",
        status: :sent,
        metadata: %{channel: :telegram, bridge_id: "bridge-1"}
      })

    assert {:ok, ^room} = Postgres.save_room(state, room)
    assert {:ok, ^room} = Postgres.get_room(state, room.id)
    assert {:ok, ^message} = Postgres.save_message(state, message)
    assert {:ok, ^message} = Postgres.get_message(state, message.id)

    assert {:ok, [^message]} = Postgres.get_messages(state, room.id, limit: 10)

    assert {:ok, ^message} =
             Postgres.get_message_by_external_id(state, :telegram, "bridge-1", "ext-1")
  end

  test "persists bridge configs and room bindings", %{state: state} do
    room = Room.new(%{id: "room-2", type: :group, name: "Bridge room"})

    bridge_config =
      BridgeConfig.new(%{
        id: "bridge-1",
        adapter_module: Jido.Chat.Telegram.Adapter,
        enabled: true
      })

    assert {:ok, ^room} = Postgres.save_room(state, room)
    assert {:ok, ^bridge_config} = Postgres.save_bridge_config(state, bridge_config)
    assert {:ok, [^bridge_config]} = Postgres.list_bridge_configs(state, enabled: true)

    assert {:ok, binding} =
             Postgres.create_room_binding(state, room.id, :telegram, "bridge-1", "-1001", %{})

    assert binding.room_id == room.id
    assert binding.channel == :telegram
    assert binding.bridge_id == "bridge-1"
    assert binding.external_room_id == "-1001"

    assert {:ok, [^binding]} = Postgres.list_room_bindings(state, room.id)

    assert {:ok, ^room} =
             Postgres.get_room_by_external_binding(state, :telegram, "bridge-1", "-1001")
  end
end
