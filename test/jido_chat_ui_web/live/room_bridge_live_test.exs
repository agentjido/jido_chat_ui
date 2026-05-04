defmodule JidoChatUIWeb.RoomBridgeLiveTest do
  use JidoChatUIWeb.ConnCase

  import JidoChatUI.BridgesFixtures
  import JidoChatUI.ChatFixtures
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "binds a configured bridge to a room with an active default", %{conn: conn, scope: scope} do
    room = room_fixture(scope)
    _bridge = bridge_fixture(scope, %{name: "GitHub repo bridge", adapter: "github"})

    {:ok, room_bridge_live, html} = live(conn, ~p"/rooms/#{room}/bridges")

    assert html =~ "Add a bridge"

    assert {:ok, room_bridge_live, _html} =
             room_bridge_live
             |> form("#room-bridge-form",
               room_bridge: %{
                 external_room_id: "agentjido/jido_chat_ui",
                 external_thread_id: "1"
               }
             )
             |> render_submit()
             |> follow_redirect(conn, ~p"/rooms/#{room}/bridges")

    html = render(room_bridge_live)

    assert html =~ "Bridge bound to room"
    assert html =~ "GitHub repo bridge"
    assert html =~ "agentjido/jido_chat_ui"
    assert html =~ "active"
  end
end
