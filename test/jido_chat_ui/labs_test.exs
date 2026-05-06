defmodule JidoChatUI.LabsTest do
  use JidoChatUI.DataCase

  alias JidoChatUI.{Bridges, Chat, Labs, Messaging, Workspace}
  alias JidoChatUI.Messaging.Sync

  setup do
    %{scope: Workspace.scope!()}
  end

  test "list/1 exposes bundled adapter labs and leaves optional Signal out", %{scope: scope} do
    labs = Labs.list(scope: scope)

    assert Enum.any?(labs, &(&1.adapter_id == "github"))
    assert Enum.any?(labs, &(&1.adapter_id == "telegram"))
    refute Enum.any?(labs, &(&1.adapter_id == "signal"))
  end

  test "default_target/2 reads primary and alternate env vars" do
    env = fn
      "TELEGRAM_TEST_CHAT_ID" -> "telegram-target"
      "TELEGRAM_BRIDGE_CHAT_ID" -> "telegram-bridge-target"
      "X_TEST_RECIPIENT_ID" -> "x-recipient"
      _key -> nil
    end

    assert Labs.default_target("telegram", env) == "telegram-target"
    assert Labs.default_target("x", env) == "x-recipient"
    assert Labs.default_target("github", env) == ""
    assert Labs.bridge_target_env("telegram") == "TELEGRAM_BRIDGE_CHAT_ID"
    assert Labs.bridge_default_target("telegram", env) == "telegram-bridge-target"
    assert Labs.bridge_default_target("discord", env) == ""
  end

  test "ensure_lab/3 creates and reuses a room, bridge, and target binding", %{scope: scope} do
    assert {:ok, lab} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "telegram-chat-123"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert lab.room.name == "Telegram Lab"
    assert lab.room.metadata["lab_adapter"] == "telegram"
    assert lab.bridge.name == "Telegram Lab Bridge"
    assert lab.bridge.adapter == "telegram"
    assert lab.binding.external_room_id == "telegram-chat-123"
    assert lab.binding.status == "active"

    assert {:ok, reused} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "telegram-chat-123"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert reused.room.id == lab.room.id
    assert reused.bridge.id == lab.bridge.id
    assert reused.binding.id == lab.binding.id
    assert Enum.count(Chat.list_rooms(scope), &(&1.metadata["lab_adapter"] == "telegram")) == 1

    assert Enum.count(Bridges.list_bridges(scope), &(&1.metadata["lab_adapter"] == "telegram")) ==
             1
  end

  test "ensure_lab/3 updates an existing lab binding when the target changes", %{scope: scope} do
    assert {:ok, lab} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "old-target"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert lab.binding.external_room_id == "old-target"

    assert {:ok, updated} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "new-target"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert updated.room.id == lab.room.id
    assert updated.bridge.id == lab.bridge.id
    assert updated.binding.id == lab.binding.id
    assert updated.binding.external_room_id == "new-target"

    assert {:ok, [runtime_binding]} =
             JidoChatUI.Messaging.list_room_bindings(to_string(lab.room.id))

    assert runtime_binding.external_room_id == "new-target"
  end

  test "ensure_lab/3 ignores shared multi-adapter rooms for dedicated labs", %{scope: scope} do
    assert {:ok, room} =
             Chat.create_room(scope, %{
               name: "Shared Lab",
               description: "One room for multiple live adapters.",
               status: "active",
               metadata: %{"lab_adapter" => "telegram", "lab_adapters" => ["telegram", "discord"]}
             })

    assert {:ok, discord_lab} =
             Labs.ensure_lab(
               "discord",
               %{"external_room_id" => "discord-channel-123"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    refute discord_lab.room.id == room.id
    assert discord_lab.room.name == "Discord Lab"
    assert discord_lab.room.metadata["lab_adapter"] == "discord"
    assert discord_lab.bridge.adapter == "discord"
    assert discord_lab.binding.external_room_id == "discord-channel-123"
  end

  test "ensure_active_connector_rooms/1 creates dedicated rooms for configured adapters only", %{
    scope: scope
  } do
    env = fn
      "TELEGRAM_BOT_TOKEN" -> "telegram-token"
      "TELEGRAM_TEST_CHAT_ID" -> "telegram-chat-123"
      "DISCORD_BOT_TOKEN" -> "discord-token"
      "DISCORD_TEST_CHANNEL_ID" -> "discord-channel-123"
      _key -> nil
    end

    assert {:ok, labs} = Labs.ensure_active_connector_rooms(scope: scope, env_fun: env)

    adapter_ids = Enum.map(labs, & &1.adapter_id)
    assert "telegram" in adapter_ids
    assert "discord" in adapter_ids
    refute "github" in adapter_ids

    assert Enum.all?(labs, &(&1.room.metadata["lab_adapter"] == &1.adapter_id))
    assert Enum.all?(labs, &(&1.binding.status == "active"))
  end

  test "sync_room_topology/1 applies room routing policy metadata", %{scope: scope} do
    assert {:ok, room} =
             Chat.create_room(scope, %{
               name: "Broadcast Lab",
               description: "One room for multiple live adapters.",
               status: "active",
               metadata: %{
                 "routing_policy" => %{
                   "delivery_mode" => "broadcast",
                   "failover_policy" => "broadcast"
                 }
               }
             })

    assert {:ok, _room} = Sync.sync_room_topology(room)
    assert {:ok, policy} = Messaging.get_routing_policy(to_string(room.id))
    assert policy.delivery_mode == :broadcast
    assert policy.failover_policy == :broadcast
  end

  test "ensure_lab/3 rehydrates runtime bindings for an existing lab binding", %{scope: scope} do
    assert {:ok, lab} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "rehydrate-target"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert {:ok, [runtime_binding]} =
             JidoChatUI.Messaging.list_room_bindings(to_string(lab.room.id))

    :ok = JidoChatUI.Messaging.delete_room_binding(runtime_binding.id)
    assert {:ok, []} = JidoChatUI.Messaging.list_room_bindings(to_string(lab.room.id))

    assert {:ok, rehydrated} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "rehydrate-target"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert rehydrated.binding.id == lab.binding.id

    assert {:ok, [runtime_binding]} =
             JidoChatUI.Messaging.list_room_bindings(to_string(lab.room.id))

    assert runtime_binding.external_room_id == "rehydrate-target"
  end

  test "state/2 marks failed outbound smoke messages as failed readiness", %{scope: scope} do
    assert {:ok, lab} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "telegram-chat-123"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert {:ok, _message} =
             Messaging.save_message(%{
               room_id: to_string(lab.room.id),
               sender_id: "ui:user:test",
               role: :user,
               content: [%{type: :text, text: "failed smoke"}],
               status: :failed,
               metadata: %{
                 "source" => "ui",
                 "route_decision" => "delivery_failed",
                 "delivery_error" => ":delivery_failed",
                 "failed_routes" => [%{"reason" => "Bad Request: chat not found"}]
               }
             })

    lab = Labs.state("telegram", scope: scope, env_fun: fn _key -> nil end)
    outbound_step = Enum.find(lab.steps, &(&1.label == "Outbound smoke"))

    assert outbound_step.status == :failed
    assert outbound_step.detail =~ "chat not found"
  end
end
