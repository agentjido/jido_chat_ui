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
      log_sync_result("room routing policy", sync_routing_policy(room))

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

  def sync_routing_policy(%Room{} = room) do
    case routing_policy_attrs(room) do
      nil -> :ok
      attrs -> Messaging.put_routing_policy(room_id(room), attrs)
    end
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

  defp maybe_put_ingress(opts, "discord", config) do
    opts
    |> Map.put("ingress", %{
      "mode" => string_config(config, "ingress_mode", "gateway"),
      "source" => string_config(config, "ingress_source", "nostrum"),
      "poll_interval_ms" => positive_integer_config(config, "poll_interval_ms", 250),
      "max_backoff_ms" => positive_integer_config(config, "poll_max_backoff_ms", 5_000)
    })
    |> maybe_put_discord_event_names(config)
  end

  defp maybe_put_ingress(opts, _adapter, _config), do: opts

  defp maybe_put_discord_event_names(%{"ingress" => ingress} = opts, config) do
    event_names =
      config
      |> Map.get("event_names")
      |> case do
        value when is_binary(value) ->
          value
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        value when is_list(value) ->
          value

        _other ->
          []
      end

    if event_names == [] do
      opts
    else
      Map.put(opts, "ingress", Map.put(ingress, "event_names", event_names))
    end
  end

  defp string_config(config, key, default) do
    case Map.get(config, key) do
      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: default, else: value

      _other ->
        default
    end
  end

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

  defp routing_policy_attrs(%Room{metadata: metadata}) when is_map(metadata) do
    metadata
    |> metadata_value("routing_policy")
    |> case do
      policy when is_map(policy) ->
        normalize_routing_policy_attrs(policy)

      _other ->
        metadata
        |> metadata_value("jido_messaging")
        |> case do
          nested when is_map(nested) ->
            case metadata_value(nested, "routing_policy") do
              policy when is_map(policy) -> normalize_routing_policy_attrs(policy)
              _other -> nil
            end

          _other ->
            nil
        end
    end
  end

  defp routing_policy_attrs(_room), do: nil

  defp normalize_routing_policy_attrs(policy) do
    %{}
    |> maybe_put_enum(
      :delivery_mode,
      metadata_value(policy, "delivery_mode"),
      [:best_effort, :primary, :broadcast]
    )
    |> maybe_put_enum(
      :failover_policy,
      metadata_value(policy, "failover_policy"),
      [:none, :next_available, :broadcast]
    )
    |> maybe_put_enum(
      :dedupe_scope,
      metadata_value(policy, "dedupe_scope"),
      [:message_id, :thread, :room]
    )
    |> maybe_put_list(:fallback_order, metadata_value(policy, "fallback_order"))
    |> maybe_put_map(:metadata, metadata_value(policy, "metadata"))
  end

  defp maybe_put_enum(acc, key, value, allowed) do
    case normalize_enum(value, allowed) do
      nil -> acc
      normalized -> Map.put(acc, key, normalized)
    end
  end

  defp normalize_enum(value, allowed) when is_atom(value) do
    if value in allowed, do: value
  end

  defp normalize_enum(value, allowed) when is_binary(value) do
    value = value |> String.trim() |> String.to_existing_atom()
    if value in allowed, do: value
  rescue
    ArgumentError -> nil
  end

  defp normalize_enum(_value, _allowed), do: nil

  defp maybe_put_list(acc, key, value) when is_list(value), do: Map.put(acc, key, value)
  defp maybe_put_list(acc, _key, _value), do: acc

  defp maybe_put_map(acc, key, value) when is_map(value), do: Map.put(acc, key, value)
  defp maybe_put_map(acc, _key, _value), do: acc

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

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, to_string(key))
  end

  defp metadata_value(_metadata, _key), do: nil

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
