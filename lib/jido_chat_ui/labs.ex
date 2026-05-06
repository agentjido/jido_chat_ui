defmodule JidoChatUI.Labs do
  @moduledoc """
  Adapter lab orchestration for the local workbench.

  Labs are derived from existing rooms, bridges, room bindings, adapter status,
  and persisted `jido_messaging` messages. No lab-specific table is needed.
  """

  alias JidoChatUI.{Adapters, Bridges, Chat, Messaging, Workspace}
  alias JidoChatUI.Messaging.Sync

  @target_env %{
    "github" => "GITHUB_TEST_ISSUE",
    "slack" => "SLACK_TEST_CHANNEL_ID",
    "telegram" => "TELEGRAM_TEST_CHAT_ID",
    "discord" => "DISCORD_TEST_CHANNEL_ID",
    "mattermost" => "MATTERMOST_CHANNEL_ID",
    "x" => "X_TEST_CONVERSATION_ID"
  }

  @alternate_target_env %{
    "x" => "X_TEST_RECIPIENT_ID"
  }

  @bridge_target_env %{
    "telegram" => "TELEGRAM_BRIDGE_CHAT_ID",
    "discord" => "DISCORD_BRIDGE_CHANNEL_ID"
  }

  def list(opts \\ []) do
    scope = Keyword.get_lazy(opts, :scope, &Workspace.scope!/0)
    env_fun = Keyword.get(opts, :env_fun, &System.get_env/1)

    Adapters.bundled()
    |> Enum.map(&state(&1.id, scope: scope, env_fun: env_fun))
  end

  def state(adapter_id, opts \\ []) do
    scope = Keyword.get_lazy(opts, :scope, &Workspace.scope!/0)
    env_fun = Keyword.get(opts, :env_fun, &System.get_env/1)
    adapter = Adapters.get(adapter_id)
    health = adapter && Adapters.health_status(adapter, env_fun)
    capability = adapter && Adapters.capability_status(adapter)
    room = find_lab_room(scope, adapter_id)
    bridge = find_lab_bridge(scope, adapter_id)
    binding = find_lab_binding(scope, room, bridge)
    target = binding_target(binding) || default_target(adapter_id, env_fun)
    messages = lab_messages(room)

    %{
      adapter_id: adapter_id,
      adapter: adapter,
      health: health,
      capability: capability,
      room: room,
      bridge: bridge,
      binding: binding,
      target: target,
      latest_inbound: latest_source(messages, "adapter"),
      latest_outbound: latest_source(messages, "ui"),
      steps: steps(adapter, health, capability, room, bridge, binding, target, messages)
    }
  end

  def ensure_lab(adapter_id, attrs \\ %{}, opts \\ []) do
    scope = Keyword.get_lazy(opts, :scope, &Workspace.scope!/0)
    env_fun = Keyword.get(opts, :env_fun, &System.get_env/1)

    with %{loaded?: true} = adapter <- Adapters.get(adapter_id),
         {:ok, room} <- ensure_room(scope, adapter),
         {:ok, bridge} <- ensure_bridge(scope, adapter),
         target <- target_from_attrs(attrs) || default_target(adapter_id, env_fun),
         {:ok, _binding_or_skip} <- ensure_binding(scope, room, bridge, target) do
      {:ok, state(adapter_id, scope: scope, env_fun: env_fun)}
    else
      nil -> {:error, :unknown_adapter}
      %{loaded?: false} -> {:error, :adapter_unavailable}
      {:error, _reason} = error -> error
    end
  end

  def ensure_active_connector_rooms(opts \\ []) do
    scope = Keyword.get_lazy(opts, :scope, &Workspace.scope!/0)
    env_fun = Keyword.get(opts, :env_fun, &System.get_env/1)

    Adapters.bundled()
    |> Enum.filter(&active_connector?(&1, env_fun))
    |> Enum.reduce_while({:ok, []}, fn adapter, {:ok, labs} ->
      case ensure_lab(adapter.id, %{}, scope: scope, env_fun: env_fun) do
        {:ok, lab} -> {:cont, {:ok, [lab | labs]}}
        {:error, reason} -> {:halt, {:error, {adapter.id, reason}}}
      end
    end)
    |> case do
      {:ok, labs} -> {:ok, Enum.reverse(labs)}
      {:error, _reason} = error -> error
    end
  end

  def target_env(adapter_id), do: Map.get(@target_env, adapter_id)
  def bridge_target_env(adapter_id), do: Map.get(@bridge_target_env, adapter_id)

  def default_target(adapter_id, env_fun \\ &System.get_env/1) do
    primary = @target_env |> Map.get(adapter_id) |> env_value(env_fun)
    alternate = @alternate_target_env |> Map.get(adapter_id) |> env_value(env_fun)

    present(primary) || present(alternate) || ""
  end

  def bridge_default_target(adapter_id, env_fun \\ &System.get_env/1) do
    target = @bridge_target_env |> Map.get(adapter_id) |> env_value(env_fun)

    present(target) || ""
  end

  defp steps(adapter, health, capability, room, bridge, binding, target, messages) do
    [
      step("Package", adapter && adapter.loaded?, loaded_detail(adapter)),
      step("Configuration", health && health.status == :connected, health_detail(health)),
      step(
        "Capabilities",
        capability && capability.status == :valid,
        capability_detail(capability)
      ),
      step("Lab room", not is_nil(room), exists_detail(room)),
      step("Bridge", not is_nil(bridge), exists_detail(bridge)),
      step("External target", present?(target), target_detail(target)),
      step("Binding", not is_nil(binding), binding_detail(binding)),
      step(
        "Outbound smoke",
        smoke_status(latest_source(messages, "ui")),
        smoke_detail(latest_source(messages, "ui"))
      ),
      step(
        "Inbound smoke",
        smoke_status(latest_source(messages, "adapter")),
        smoke_detail(latest_source(messages, "adapter"))
      ),
      step("Room Assistant", true, "Available in every lab room")
    ]
  end

  defp step(label, status, detail) when status in [:done, :todo, :failed],
    do: %{label: label, status: status, detail: detail}

  defp step(label, true, detail), do: %{label: label, status: :done, detail: detail}
  defp step(label, false, detail), do: %{label: label, status: :todo, detail: detail}
  defp step(label, nil, detail), do: %{label: label, status: :todo, detail: detail}

  defp ensure_room(scope, adapter) do
    case find_lab_room(scope, adapter.id) do
      nil ->
        Chat.create_room(scope, %{
          name: lab_room_name(adapter),
          description: "Focused #{adapter.name} adapter proof room.",
          status: "active",
          metadata: %{"lab_adapter" => adapter.id}
        })

      room ->
        {:ok, room}
    end
  end

  defp ensure_bridge(scope, adapter) do
    case find_lab_bridge(scope, adapter.id) do
      nil ->
        Bridges.create_bridge(scope, %{
          name: "#{adapter.name} Lab Bridge",
          adapter: adapter.id,
          status: "active",
          config: default_bridge_config(adapter),
          metadata: %{"lab_adapter" => adapter.id}
        })

      bridge ->
        {:ok, bridge}
    end
  end

  defp ensure_binding(_scope, _room, _bridge, target) when target in [nil, ""],
    do: {:ok, :skipped}

  defp ensure_binding(scope, room, bridge, target) do
    case find_lab_binding(scope, room, bridge) do
      nil ->
        Chat.create_room_bridge(scope, %{
          room_id: room.id,
          bridge_id: bridge.id,
          external_room_id: target,
          status: "active",
          metadata: %{"lab_adapter" => bridge.adapter}
        })

      binding when binding.external_room_id != target or binding.status != "active" ->
        Chat.update_room_bridge(scope, binding, %{
          external_room_id: target,
          status: "active",
          metadata: Map.put(binding.metadata || %{}, "lab_adapter", bridge.adapter)
        })

      binding ->
        Sync.log_sync_result("lab binding", Sync.sync_room_bridge(binding))
        {:ok, binding}
    end
  end

  defp find_lab_room(scope, adapter_id) do
    scope
    |> Chat.list_rooms()
    |> Enum.find(&lab_room_for_adapter?(&1, adapter_id))
  end

  defp lab_room_for_adapter?(room, adapter_id) do
    metadata_value(room.metadata, "lab_adapter") == adapter_id and
      lab_adapters(room.metadata) in [[], [adapter_id]]
  end

  defp lab_adapters(metadata) when is_map(metadata) do
    case metadata_value(metadata, "lab_adapters") do
      adapters when is_list(adapters) -> Enum.map(adapters, &to_string/1)
      adapter when is_binary(adapter) -> [adapter]
      _other -> []
    end
  end

  defp lab_adapters(_metadata), do: []

  defp find_lab_bridge(scope, adapter_id) do
    scope
    |> Bridges.list_bridges()
    |> Enum.find(
      &(metadata_value(&1.metadata, "lab_adapter") == adapter_id || &1.adapter == adapter_id)
    )
  end

  defp find_lab_binding(_scope, nil, _bridge), do: nil
  defp find_lab_binding(_scope, _room, nil), do: nil

  defp find_lab_binding(scope, room, bridge) do
    scope
    |> Chat.list_room_bridges_for_room(room.id)
    |> Enum.find(&(&1.bridge_id == bridge.id))
  end

  defp lab_messages(nil), do: []

  defp lab_messages(room) do
    case Messaging.list_messages(to_string(room.id), limit: 100) do
      {:ok, messages} -> messages
      {:error, _reason} -> []
    end
  end

  defp latest_source(messages, source) do
    Enum.find(Enum.reverse(messages), &(message_source(&1) == source))
  end

  defp message_source(message) do
    message.metadata
    |> metadata_value("source")
    |> case do
      nil -> if metadata_value(message.metadata, "channel"), do: "adapter", else: nil
      source -> to_string(source)
    end
  end

  defp target_from_attrs(attrs) do
    present(
      attrs["external_room_id"] || attrs[:external_room_id] || attrs["target"] || attrs[:target]
    )
  end

  defp active_connector?(adapter, env_fun) do
    adapter.loaded? and
      Adapters.health_status(adapter, env_fun).status == :connected and
      Adapters.capability_status(adapter).status == :valid and
      present?(default_target(adapter.id, env_fun))
  end

  defp default_bridge_config(adapter) do
    adapter.id
    |> Adapters.config_fields()
    |> Enum.reduce(%{}, fn field, acc ->
      value =
        cond do
          String.ends_with?(field.key, "_env") -> field.placeholder
          field.key in ["token_env", "bot_token_env", "consumer_key_env"] -> field.placeholder
          true -> nil
        end

      if present?(value), do: Map.put(acc, field.key, value), else: acc
    end)
  end

  defp env_value(nil, _env_fun), do: nil
  defp env_value(key, env_fun), do: env_fun.(key)

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, to_string(key))
  end

  defp metadata_value(_metadata, _key), do: nil

  defp binding_target(nil), do: nil
  defp binding_target(binding), do: binding.external_room_id

  defp lab_room_name(adapter), do: "#{adapter.name} Lab"
  defp present(value) when is_binary(value), do: value |> String.trim() |> blank_to_nil()
  defp present(_value), do: nil
  defp present?(value), do: not is_nil(present(value))
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp loaded_detail(nil), do: "Unknown adapter"
  defp loaded_detail(%{loaded?: true}), do: "Adapter module is loaded"
  defp loaded_detail(%{loaded?: false}), do: "Adapter package is not available"

  defp health_detail(nil), do: "No runtime requirements known"
  defp health_detail(%{status: :connected}), do: "Required env vars are present"
  defp health_detail(%{missing_env: missing}), do: "Missing #{Enum.join(missing, ", ")}"

  defp capability_detail(nil), do: "Capability matrix not checked"
  defp capability_detail(%{status: :valid}), do: "Capability matrix is valid"
  defp capability_detail(%{detail: detail}), do: detail

  defp exists_detail(nil), do: "Create or reuse from this lab"
  defp exists_detail(%{name: name}), do: name
  defp exists_detail(%{id: id}), do: "ID #{id}"

  defp target_detail(""), do: "Set a target ID or matching env var"
  defp target_detail(target), do: target

  defp binding_detail(nil), do: "Bind the bridge to a target"
  defp binding_detail(binding), do: "#{binding.external_room_id} is #{binding.status}"

  defp smoke_status(nil), do: :todo

  defp smoke_status(%{status: :failed}), do: :failed

  defp smoke_status(message) do
    case metadata_value(message.metadata, "route_decision") do
      "delivery_failed" -> :failed
      "delivery_error" -> :failed
      "no_routes" -> :todo
      _route_decision -> :done
    end
  end

  defp smoke_detail(nil), do: "No matching message yet"

  defp smoke_detail(%{status: :failed} = message) do
    "Delivery failed: #{delivery_failure_reason(message)}"
  end

  defp smoke_detail(message) do
    case metadata_value(message.metadata, "route_decision") do
      "delivered" ->
        "Delivered to #{metadata_value(message.metadata, "delivered") || 1} route(s)"

      "delivery_failed" ->
        "Delivery failed: #{delivery_failure_reason(message)}"

      "delivery_error" ->
        "Delivery error: #{metadata_value(message.metadata, "delivery_error") || "unknown"}"

      "no_routes" ->
        "No outbound route was available"

      _route_decision ->
        message.id
    end
  end

  defp delivery_failure_reason(message) do
    failed_routes = metadata_value(message.metadata, "failed_routes") || []

    failed_routes
    |> List.first()
    |> case do
      %{} = route -> metadata_value(route, "reason")
      _other -> metadata_value(message.metadata, "delivery_error")
    end
    |> friendly_failure_reason()
  end

  defp friendly_failure_reason(nil), do: "unknown"

  defp friendly_failure_reason(reason) do
    reason = to_string(reason)

    cond do
      String.contains?(reason, "chat not found") -> "chat not found"
      String.length(reason) > 120 -> String.slice(reason, 0, 117) <> "..."
      true -> reason
    end
  end
end
