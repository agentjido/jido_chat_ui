defmodule JidoChatUI.RoomTimelineTest do
  use ExUnit.Case, async: true

  alias JidoChatUI.RoomTimeline

  test "ensure_started/2 returns the same observable process for a room" do
    room_id = unique_room_id()

    pid = RoomTimeline.ensure_started(room_id, "Test room")
    assert ^pid = RoomTimeline.ensure_started(room_id, "Test room")
    assert :sys.get_state(pid).room_id == room_id
  end

  test "post_message/2 appends a message to the room timeline" do
    room_id = unique_room_id()
    pid = RoomTimeline.ensure_started(room_id, "Test room")

    assert {:ok, message} =
             RoomTimeline.post_message(pid, %{
               author: "tester@example.com",
               body: "hello from test",
               source: "ui",
               status: "sent"
             })

    state = :sys.get_state(pid)

    assert message.body == "hello from test"
    assert Enum.any?(state.messages, &(&1.id == message.id))
  end

  test "post_message/2 replaces an existing timeline message with the same id" do
    room_id = unique_room_id()
    pid = RoomTimeline.ensure_started(room_id, "Test room")

    assert {:ok, _message} =
             RoomTimeline.post_message(pid, %{
               id: "same-message",
               author: "tester@example.com",
               body: "hello from test",
               source: "ui",
               status: "sent"
             })

    assert {:ok, _message} =
             RoomTimeline.post_message(pid, %{
               id: "same-message",
               author: "tester@example.com",
               body: "hello from test",
               source: "ui",
               status: "delivered:1",
               metadata: %{"route_decision" => "delivered"}
             })

    messages =
      pid
      |> :sys.get_state()
      |> Map.fetch!(:messages)
      |> Enum.filter(&(&1.id == "same-message"))

    assert [%{status: "delivered:1", metadata: %{"route_decision" => "delivered"}}] = messages
  end

  defp unique_room_id do
    "test-room-#{System.unique_integer([:positive, :monotonic])}"
  end
end
