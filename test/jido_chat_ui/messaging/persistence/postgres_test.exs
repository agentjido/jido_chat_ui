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

  test "reassigns an existing external binding to the requested room", %{state: state} do
    first_room = Room.new(%{id: "room-original", type: :group, name: "Original"})
    next_room = Room.new(%{id: "room-next", type: :group, name: "Next"})

    assert {:ok, ^first_room} = Postgres.save_room(state, first_room)
    assert {:ok, ^next_room} = Postgres.save_room(state, next_room)

    assert {:ok, original_binding} =
             Postgres.create_room_binding(
               state,
               first_room.id,
               :telegram,
               "bridge-1",
               "-1001",
               %{direction: :inbound, enabled: false}
             )

    assert original_binding.room_id == first_room.id
    assert original_binding.direction == :inbound
    assert original_binding.enabled == false

    assert {:ok, reassigned_binding} =
             Postgres.create_room_binding(
               state,
               next_room.id,
               :telegram,
               "bridge-1",
               "-1001",
               %{direction: :both, enabled: true}
             )

    assert reassigned_binding.id == original_binding.id
    assert reassigned_binding.room_id == next_room.id
    assert reassigned_binding.direction == :both
    assert reassigned_binding.enabled == true

    assert {:ok, []} = Postgres.list_room_bindings(state, first_room.id)
    assert {:ok, [^reassigned_binding]} = Postgres.list_room_bindings(state, next_room.id)

    assert {:ok, ^next_room} =
             Postgres.get_room_by_external_binding(state, :telegram, "bridge-1", "-1001")
  end
end
