defmodule JidoChatUI.Messaging.Sync do
  @moduledoc """
  Keeps the Phoenix developer UI schemas aligned with `JidoChatUI.Messaging`.

  The UI keeps ergonomic Ecto records for forms, ownership, and setup screens.
  This module mirrors those records into the canonical `jido_messaging` room,
  bridge config, and room binding models used by runtime routing.
  """

  require Logger

  alias Jido.Messaging.BridgeConfig
  alias Jido.Chat.Room, as: MessagingRoom
  alias JidoChatUI.Adapters
  alias JidoChatUI.Bridges.Bridge
  alias JidoChatUI.Chat.{Room, RoomBridge}
  alias JidoChatUI.{Bridges, Chat, Messaging}

  def room_id(%Room{id: id}), do: to_string(id)
  def bridge_id(%Bridge{id: id}), do: "ui_bridge:#{id}"

  def sync_room(%Room{} = room) do
    room
    |> to_messaging_room()
    |> Messaging.save_room()
  end

  def sync_room_topology(%Room{} = room) do
    with {:ok, _room} <- sync_room(room) do
      room
      |> room_bridges_for_room()
      |> Enum.each(fn room_bridge ->
        log_sync_result("room bridge topology", sync_room_bridge(room_bridge))
      end)

      {:ok, room}
    end
  end

  def sync_bridge(%Bridge{} = bridge) do
    with {:ok, adapter} <- adapter_for(bridge.adapter) do
      save_bridge_config(%{
        id: bridge_id(bridge),
        adapter_module: adapter.module,
        credentials: %{},
        opts: bridge_opts(bridge),
        enabled: bridge.status == "active"
      })
    end
  end

  def sync_room_bridge(%RoomBridge{} = room_bridge) do
    with room <- fetch_room(room_bridge),
         bridge <- fetch_bridge(room_bridge),
         {:ok, adapter} <- adapter_for(bridge.adapter),
         {:ok, _room} <- sync_room(room),
         {:ok, _bridge_config} <- sync_bridge(bridge),
         {:ok, binding} <-
           Messaging.create_room_binding(
             room_id(room),
             channel_for(adapter.id),
             bridge_id(bridge),
             room_bridge.external_room_id,
             %{
               direction: :both,
               enabled: room_bridge.status == "active"
             }
           ) do
      {:ok, binding}
    end
  end

  def sync_room_bridge(_room_bridge), do: {:error, :invalid_room_bridge}

  def delete_room(%Room{} = room) do
    Messaging.delete_room(room_id(room))
  end

  def delete_bridge(%Bridge{} = bridge) do
    delete_bridge_config(bridge_id(bridge))
  end

  def delete_room_binding(%RoomBridge{} = room_bridge) do
    case room_bridge_binding(room_bridge) do
      {:ok, binding} -> Messaging.delete_room_binding(binding.id)
      {:error, :not_found} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def log_sync_result(action, result) do
    case result do
      {:ok, _value} ->
        :ok

      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("jido_messaging sync failed for #{action}: #{inspect(reason)}")
        :ok
    end
  end

  defp to_messaging_room(%Room{} = room) do
    metadata =
      (room.metadata || %{})
      |> Map.put("ui_room_id", room.id)
      |> Map.put("ui_user_id", room.user_id)
      |> Map.put("status", room.status)
      |> put_if_present("description", room.description)

    MessagingRoom.new(%{
      id: room_id(room),
      type: :group,
      name: room.name,
      metadata: metadata,
      inserted_at: room.inserted_at
    })
  end

  defp adapter_for(adapter_id) do
    case Adapters.get(adapter_id) do
      %{loaded?: true} = adapter -> {:ok, adapter}
      %{loaded?: false} -> {:error, {:adapter_unavailable, adapter_id}}
      nil -> {:error, {:unknown_adapter, adapter_id}}
    end
  end

  defp bridge_opts(%Bridge{} = bridge) do
    config = bridge.config || %{}

    %{
      "ui_bridge_id" => bridge.id,
      "ui_user_id" => bridge.user_id,
      "adapter" => bridge.adapter,
      "config" => config,
      "metadata" => bridge.metadata || %{}
    }
    |> maybe_put_ingress(bridge.adapter, config)
  end

  defp maybe_put_ingress(opts, "telegram", config) do
    mode =
      config
      |> Map.get("ingress_mode", "polling")
      |> to_string()
      |> String.trim()

    mode = if mode == "", do: "polling", else: mode

    Map.put(opts, "ingress", %{
      "mode" => mode,
      "timeout_s" => positive_integer_config(config, "poll_timeout_s", 2),
      "poll_interval_ms" => positive_integer_config(config, "poll_interval_ms", 1_000),
      "max_backoff_ms" => positive_integer_config(config, "poll_max_backoff_ms", 5_000),
      "allowed_updates" => ["message", "edited_message", "channel_post", "edited_channel_post"]
    })
  end

  defp maybe_put_ingress(opts, _adapter, _config), do: opts

  defp positive_integer_config(config, key, default) do
    case Map.get(config, key) do
      value when is_integer(value) and value > 0 ->
        value

      value when is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {parsed, ""} when parsed > 0 -> parsed
          _other -> default
        end

      _other ->
        default
    end
  end

  defp save_bridge_config(attrs) do
    case Application.get_env(:jido_chat_ui, :messaging_sync_mode, :runtime) do
      :direct_persistence ->
        {persistence, state} =
          Jido.Messaging.Runtime.get_persistence(Messaging.__jido_messaging__(:runtime))

        persistence.save_bridge_config(state, BridgeConfig.new(attrs))

      _runtime ->
        Messaging.put_bridge_config(attrs)
    end
  end

  defp delete_bridge_config(bridge_id) do
    case Application.get_env(:jido_chat_ui, :messaging_sync_mode, :runtime) do
      :direct_persistence ->
        {persistence, state} =
          Jido.Messaging.Runtime.get_persistence(Messaging.__jido_messaging__(:runtime))

        case persistence.delete_bridge_config(state, bridge_id) do
          {:error, :not_found} -> :ok
          other -> other
        end

      _runtime ->
        Messaging.delete_bridge_config(bridge_id)
    end
  end

  defp fetch_room(%RoomBridge{} = room_bridge) do
    Chat.get_room!(scope_for(room_bridge), room_bridge.room_id)
  end

  defp fetch_bridge(%RoomBridge{} = room_bridge) do
    Bridges.get_bridge!(scope_for(room_bridge), room_bridge.bridge_id)
  end

  defp room_bridges_for_room(%Room{} = room) do
    Chat.list_room_bridges_for_room(scope_for(room), room.id)
  end

  defp scope_for(%{user_id: user_id}) do
    %JidoChatUI.Accounts.Scope{user: %{id: user_id}}
  end

  defp room_bridge_binding(%RoomBridge{} = room_bridge) do
    bridge = fetch_bridge(room_bridge)

    with {:ok, adapter} <- adapter_for(bridge.adapter) do
      Messaging.get_room_by_external_binding(
        channel_for(adapter.id),
        bridge_id(bridge),
        room_bridge.external_room_id
      )
      |> case do
        {:ok, _room} ->
          find_binding(room_bridge, bridge, adapter)

        {:error, :not_found} = error ->
          error
      end
    end
  end

  defp find_binding(%RoomBridge{} = room_bridge, %Bridge{} = bridge, adapter) do
    case Messaging.list_room_bindings(to_string(room_bridge.room_id)) do
      {:ok, bindings} ->
        bindings
        |> Enum.find(fn binding ->
          binding.channel == channel_for(adapter.id) and
            binding.bridge_id == bridge_id(bridge) and
            binding.external_room_id == room_bridge.external_room_id
        end)
        |> case do
          nil -> {:error, :not_found}
          binding -> {:ok, binding}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp channel_for("discord"), do: :discord
  defp channel_for("github"), do: :github
  defp channel_for("mattermost"), do: :mattermost
  defp channel_for("slack"), do: :slack
  defp channel_for("telegram"), do: :telegram
  defp channel_for("x"), do: :x

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
