defmodule JidoChatUI.WorkspaceTest do
  use JidoChatUI.DataCase

  alias JidoChatUI.{Chat, Workspace}

  test "scope!/0 creates and reuses the internal workspace user" do
    first = Workspace.scope!()
    second = Workspace.scope!()

    assert first.user.id == second.user.id
    assert first.user.email == "workspace@jido-chat-ui.local"
    assert first.user.confirmed_at
  end

  test "workspace scope can own existing scoped records" do
    scope = Workspace.scope!()

    assert {:ok, room} =
             Chat.create_room(scope, %{
               name: "Workspace room",
               description: "Owned by the local workspace identity.",
               status: "active",
               metadata: %{}
             })

    assert room.user_id == scope.user.id
  end
end
