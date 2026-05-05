defmodule JidoChatUIWeb.RoomLiveTest do
  use JidoChatUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import JidoChatUI.ChatFixtures

  alias JidoChatUI.Chat
  alias JidoChatUI.RoomTimeline
  alias JidoChatUI.Messaging

  @create_attrs %{
    name: "some name",
    status: "draft",
    description: "some description"
  }
  @update_attrs %{
    name: "some updated name",
    status: "active",
    description: "some updated description"
  }
  @invalid_attrs %{name: nil, status: "draft", description: nil}

  setup :register_and_log_in_user

  defp create_room(%{scope: scope}) do
    room = room_fixture(scope)

    %{room: room}
  end

  describe "Index" do
    setup [:create_room]

    test "lists all rooms", %{conn: conn, room: room} do
      {:ok, _index_live, html} = live(conn, ~p"/rooms")

      assert html =~ "Listing Rooms"
      assert html =~ room.name
    end

    test "saves new room", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/rooms")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Room")
               |> render_click()
               |> follow_redirect(conn, ~p"/rooms/new")

      assert render(form_live) =~ "New Room"

      assert form_live
             |> form("#room-form", room: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#room-form", room: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rooms")

      html = render(index_live)
      assert html =~ "Room created successfully"
      assert html =~ "some name"
    end

    test "updates room in listing", %{conn: conn, room: room} do
      {:ok, index_live, _html} = live(conn, ~p"/rooms")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#rooms-#{room.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/rooms/#{room}/edit")

      assert render(form_live) =~ "Edit Room"

      assert form_live
             |> form("#room-form", room: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#room-form", room: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rooms")

      html = render(index_live)
      assert html =~ "Room updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes room in listing", %{conn: conn, room: room} do
      {:ok, index_live, _html} = live(conn, ~p"/rooms")

      assert index_live |> element("#rooms-#{room.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#rooms-#{room.id}")
    end
  end

  describe "Show" do
    setup [:create_room]

    test "displays room", %{conn: conn, room: room} do
      {:ok, _show_live, html} = live(conn, ~p"/rooms/#{room}")

      assert html =~ "Show Room"
      assert html =~ room.name
      assert html =~ "Timeline"
      assert html =~ ~s(phx-hook="ChatComposer")
      assert html =~ ~s(phx-hook="ChatTimeline")
      assert html =~ "Room Assistant"
      assert html =~ "Summarize"
      assert html =~ "Rules"
      assert html =~ "LLM"
      assert html =~ "Relay replies"
      assert html =~ "Auto-reply to adapters"
    end

    test "composer posts to the Filament room timeline", %{conn: conn, room: room} do
      {:ok, show_live, _html} = live(conn, ~p"/rooms/#{room}")

      assert show_live
             |> form("#timeline-composer-form", %{"body" => "hello from live test"})
             |> render_submit()

      messages =
        room.id
        |> RoomTimeline.ensure_started(room.name)
        |> :sys.get_state()
        |> Map.fetch!(:messages)

      assert Enum.any?(messages, &(&1.body == "hello from live test"))

      assert {:ok, persisted_messages} = Messaging.list_messages(to_string(room.id))
      assert Enum.any?(persisted_messages, &text_content?(&1, "hello from live test"))
    end

    test "assistant action posts an agent message", %{conn: conn, room: room} do
      {:ok, show_live, _html} = live(conn, ~p"/rooms/#{room}")

      assert show_live
             |> element("button", "Summarize")
             |> render_click()

      messages =
        room.id
        |> RoomTimeline.ensure_started(room.name)
        |> :sys.get_state()
        |> Map.fetch!(:messages)

      assert Enum.any?(messages, &(&1.source == "agent"))

      assert {:ok, persisted_messages} = Messaging.list_messages(to_string(room.id))

      assert Enum.any?(persisted_messages, fn message ->
               message.sender_id == "room_assistant" and text_contains?(message, "Room check")
             end)
    end

    test "assistant settings persist mode and relay choices", %{
      conn: conn,
      room: room,
      scope: scope
    } do
      {:ok, show_live, _html} = live(conn, ~p"/rooms/#{room}")

      assert show_live
             |> element("button", "LLM")
             |> render_click()

      room = Chat.get_room!(scope, room.id)
      assert room.metadata["agent"]["agent_mode"] == "llm"
      assert room.metadata["agent"]["relay_agent_replies"] == false
      assert room.metadata["agent"]["auto_reply_adapter_messages"] == false

      assert show_live
             |> element(~s(button[phx-click="toggle_agent_relay"]), "Enable")
             |> render_click()

      room = Chat.get_room!(scope, room.id)
      assert room.metadata["agent"]["relay_agent_replies"] == true
      assert render(show_live) =~ "relay on"

      assert show_live
             |> element(~s(button[phx-click="toggle_agent_auto_reply"]), "Enable")
             |> render_click()

      room = Chat.get_room!(scope, room.id)
      assert room.metadata["agent"]["auto_reply_adapter_messages"] == true
      assert render(show_live) =~ "auto on"
    end

    test "llm mode is explicit and guarded when provider keys are absent", %{
      conn: conn,
      room: room,
      scope: scope
    } do
      with_provider_keys(nil, fn ->
        {:ok, room} =
          Chat.update_room(scope, room, %{
            metadata: %{"agent" => %{"agent_mode" => "llm", "relay_agent_replies" => false}}
          })

        {:ok, show_live, _html} = live(conn, ~p"/rooms/#{room}")

        assert show_live
               |> element("button", "Summarize")
               |> render_click()

        assert {:ok, persisted_messages} = Messaging.list_messages(to_string(room.id))

        assert Enum.any?(persisted_messages, fn message ->
                 message.sender_id == "room_assistant" and
                   message.metadata["agent_mode"] == "llm_unavailable" and
                   text_contains?(message, "no model provider key")
               end)
      end)
    end

    test "updates room and returns to show", %{conn: conn, room: room} do
      {:ok, show_live, _html} = live(conn, ~p"/rooms/#{room}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/rooms/#{room}/edit?return_to=show")

      assert render(form_live) =~ "Edit Room"

      assert form_live
             |> form("#room-form", room: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#room-form", room: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/rooms/#{room}")

      html = render(show_live)
      assert html =~ "Room updated successfully"
      assert html =~ "some updated name"
    end
  end

  defp text_content?(message, expected_text) do
    Enum.any?(message.content, fn
      %{type: :text, text: ^expected_text} -> true
      %{"type" => "text", "text" => ^expected_text} -> true
      _content -> false
    end)
  end

  defp text_contains?(message, expected_text) do
    Enum.any?(message.content, fn
      %{type: :text, text: text} when is_binary(text) ->
        String.contains?(text, expected_text)

      %{"type" => "text", "text" => text} when is_binary(text) ->
        String.contains?(text, expected_text)

      _content ->
        false
    end)
  end

  defp with_provider_keys(value, fun) when is_function(fun, 0) do
    keys = ["ANTHROPIC_API_KEY", "OPENAI_API_KEY"]
    original = Map.new(keys, &{&1, System.get_env(&1)})

    try do
      Enum.each(keys, fn key ->
        if value do
          System.put_env(key, value)
        else
          System.delete_env(key)
        end
      end)

      fun.()
    after
      Enum.each(original, fn
        {key, nil} -> System.delete_env(key)
        {key, previous} -> System.put_env(key, previous)
      end)
    end
  end
end
