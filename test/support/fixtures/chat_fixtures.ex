defmodule JidoChatUI.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `JidoChatUI.Chat` context.
  """

  alias JidoChatUI.BridgesFixtures

  @doc """
  Generate a room.
  """
  def room_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        metadata: %{},
        name: "some name",
        status: "draft"
      })

    {:ok, room} = JidoChatUI.Chat.create_room(scope, attrs)
    room
  end

  @doc """
  Generate a room_bridge.
  """
  def room_bridge_fixture(scope, attrs \\ %{}) do
    {room, attrs} = Map.pop(attrs, :room)
    {bridge, attrs} = Map.pop(attrs, :bridge)

    room = room || room_fixture(scope)
    bridge = bridge || BridgesFixtures.bridge_fixture(scope)

    attrs =
      Enum.into(attrs, %{
        bridge_id: bridge.id,
        external_room_id: "some external_room_id",
        external_thread_id: "some external_thread_id",
        metadata: %{},
        room_id: room.id,
        status: "draft"
      })

    {:ok, room_bridge} = JidoChatUI.Chat.create_room_bridge(scope, attrs)
    room_bridge
  end
end
