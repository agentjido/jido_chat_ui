defmodule JidoChatUI.ChatTest do
  use JidoChatUI.DataCase

  alias JidoChatUI.Chat
  alias JidoChatUI.Messaging

  describe "rooms" do
    alias JidoChatUI.Chat.Room

    import JidoChatUI.AccountsFixtures, only: [user_scope_fixture: 0]
    import JidoChatUI.ChatFixtures

    @invalid_attrs %{name: nil, status: nil, description: nil, metadata: nil}

    test "list_rooms/1 returns all scoped rooms" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      other_room = room_fixture(other_scope)
      assert Chat.list_rooms(scope) == [room]
      assert Chat.list_rooms(other_scope) == [other_room]
    end

    test "get_room!/2 returns the room with given id" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      other_scope = user_scope_fixture()
      assert Chat.get_room!(scope, room.id) == room
      assert_raise Ecto.NoResultsError, fn -> Chat.get_room!(other_scope, room.id) end
    end

    test "create_room/2 with valid data creates a room" do
      valid_attrs = %{
        name: "some name",
        status: "some status",
        description: "some description",
        metadata: %{}
      }

      scope = user_scope_fixture()

      assert {:ok, %Room{} = room} = Chat.create_room(scope, valid_attrs)
      assert room.name == "some name"
      assert room.status == "some status"
      assert room.description == "some description"
      assert room.metadata == %{}
      assert room.user_id == scope.user.id
    end

    test "create_room/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.create_room(scope, @invalid_attrs)
    end

    test "update_room/3 with valid data updates the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        status: "some updated status",
        description: "some updated description",
        metadata: %{}
      }

      assert {:ok, %Room{} = room} = Chat.update_room(scope, room, update_attrs)
      assert room.name == "some updated name"
      assert room.status == "some updated status"
      assert room.description == "some updated description"
      assert room.metadata == %{}
    end

    test "update_room/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)

      assert_raise MatchError, fn ->
        Chat.update_room(other_scope, room, %{})
      end
    end

    test "update_room/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Chat.update_room(scope, room, @invalid_attrs)
      assert room == Chat.get_room!(scope, room.id)
    end

    test "delete_room/2 deletes the room" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert {:ok, %Room{}} = Chat.delete_room(scope, room)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_room!(scope, room.id) end
    end

    test "delete_room/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room = room_fixture(scope)
      assert_raise MatchError, fn -> Chat.delete_room(other_scope, room) end
    end

    test "change_room/2 returns a room changeset" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      assert %Ecto.Changeset{} = Chat.change_room(scope, room)
    end
  end

  describe "room_bridges" do
    alias JidoChatUI.Chat.RoomBridge

    import JidoChatUI.AccountsFixtures, only: [user_scope_fixture: 0]
    import JidoChatUI.BridgesFixtures
    import JidoChatUI.ChatFixtures

    @invalid_attrs %{status: nil, metadata: nil, external_room_id: nil, external_thread_id: nil}

    test "list_room_bridges/1 returns all scoped room_bridges" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)
      other_room_bridge = room_bridge_fixture(other_scope)
      assert Chat.list_room_bridges(scope) == [room_bridge]
      assert Chat.list_room_bridges(other_scope) == [other_room_bridge]
    end

    test "get_room_bridge!/2 returns the room_bridge with given id" do
      scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)
      other_scope = user_scope_fixture()
      assert Chat.get_room_bridge!(scope, room_bridge.id) == room_bridge

      assert_raise Ecto.NoResultsError, fn ->
        Chat.get_room_bridge!(other_scope, room_bridge.id)
      end
    end

    test "create_room_bridge/2 with valid data creates a room_bridge" do
      scope = user_scope_fixture()
      room = room_fixture(scope)
      bridge = bridge_fixture(scope)

      valid_attrs = %{
        bridge_id: bridge.id,
        status: "some status",
        metadata: %{},
        room_id: room.id,
        external_room_id: "some external_room_id",
        external_thread_id: "some external_thread_id"
      }

      assert {:ok, %RoomBridge{} = room_bridge} = Chat.create_room_bridge(scope, valid_attrs)
      assert room_bridge.bridge_id == bridge.id
      assert room_bridge.status == "some status"
      assert room_bridge.metadata == %{}
      assert room_bridge.room_id == room.id
      assert room_bridge.external_room_id == "some external_room_id"
      assert room_bridge.external_thread_id == "some external_thread_id"
      assert room_bridge.user_id == scope.user.id
    end

    test "create_room_bridge/2 mirrors active topology into jido_messaging" do
      scope = user_scope_fixture()
      room = room_fixture(scope, %{status: "active"})
      bridge = bridge_fixture(scope, %{adapter: "github", status: "active"})

      assert {:ok, %RoomBridge{}} =
               Chat.create_room_bridge(scope, %{
                 bridge_id: bridge.id,
                 status: "active",
                 metadata: %{},
                 room_id: room.id,
                 external_room_id: "agentjido/jido_chat_ui#1",
                 external_thread_id: nil
               })

      assert {:ok, [binding]} = Messaging.list_room_bindings(to_string(room.id))
      assert binding.channel == :github
      assert binding.bridge_id == "ui_bridge:#{bridge.id}"
      assert binding.external_room_id == "agentjido/jido_chat_ui#1"
      assert binding.enabled

      assert {:ok, bridge_config} = Messaging.get_bridge_config("ui_bridge:#{bridge.id}")
      assert bridge_config.adapter_module == Jido.Chat.GitHub.Adapter
      assert bridge_config.enabled
    end

    test "create_room_bridge/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.create_room_bridge(scope, @invalid_attrs)
    end

    test "update_room_bridge/3 with valid data updates the room_bridge" do
      scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)

      update_attrs = %{
        status: "some updated status",
        metadata: %{},
        external_room_id: "some updated external_room_id",
        external_thread_id: "some updated external_thread_id"
      }

      assert {:ok, %RoomBridge{} = room_bridge} =
               Chat.update_room_bridge(scope, room_bridge, update_attrs)

      assert room_bridge.status == "some updated status"
      assert room_bridge.metadata == %{}
      assert room_bridge.external_room_id == "some updated external_room_id"
      assert room_bridge.external_thread_id == "some updated external_thread_id"
    end

    test "update_room_bridge/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)

      assert_raise MatchError, fn ->
        Chat.update_room_bridge(other_scope, room_bridge, %{})
      end
    end

    test "update_room_bridge/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Chat.update_room_bridge(scope, room_bridge, @invalid_attrs)

      assert room_bridge == Chat.get_room_bridge!(scope, room_bridge.id)
    end

    test "delete_room_bridge/2 deletes the room_bridge" do
      scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)
      assert {:ok, %RoomBridge{}} = Chat.delete_room_bridge(scope, room_bridge)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_room_bridge!(scope, room_bridge.id) end
    end

    test "delete_room_bridge/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)
      assert_raise MatchError, fn -> Chat.delete_room_bridge(other_scope, room_bridge) end
    end

    test "change_room_bridge/2 returns a room_bridge changeset" do
      scope = user_scope_fixture()
      room_bridge = room_bridge_fixture(scope)
      assert %Ecto.Changeset{} = Chat.change_room_bridge(scope, room_bridge)
    end
  end
end
