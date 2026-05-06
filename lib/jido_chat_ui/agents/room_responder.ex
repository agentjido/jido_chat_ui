defmodule JidoChatUI.Agents.RoomResponder do
  @moduledoc """
  Minimal room assistant responder for adapter-originated messages.

  This is intentionally conservative: it only responds to external adapter
  messages when a room enables auto-replies or when a message explicitly asks
  for the assistant.
  """

  use GenServer
  require Logger

  alias Jido.Messaging.Message
  alias JidoChatUI.Accounts.{Scope, User}
  alias JidoChatUI.Bridges.Bridge
  alias JidoChatUI.Chat.Room
  alias JidoChatUI.Messaging.Participants
  alias JidoChatUI.{Agents, Chat, Messaging, Repo}

  @agent_id "room_assistant"
  @subscription "jido.messaging.room.message_added"
  @trigger_pattern ~r/(^|\\b)(@?room_assistant|@?assistant|@?jido|agent)(\\b|$)/i

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :subscribe)
    {:ok, %{seen: MapSet.new()}}
  end

  @impl true
  def handle_info(:subscribe, state) do
    bus_name = Module.concat(Messaging, SignalBus)

    case Jido.Signal.Bus.subscribe(bus_name, @subscription) do
      {:ok, _subscription_id} ->
        {:noreply, state}

      {:error, _reason} ->
        Process.send_after(self(), :subscribe, 250)
        {:noreply, state}
    end
  end

  def handle_info({:signal, %{type: @subscription, data: data}}, state) do
    message = data_value(data, :message)
    message_id = message_id(message)

    cond do
      is_nil(message_id) or MapSet.member?(state.seen, message_id) ->
        {:noreply, state}

      reply_candidate?(data) ->
        _ = Task.start(fn -> reply_to_message(data) end)

        {:noreply, remember(state, message_id)}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp reply_candidate?(data) do
    with %Message{} = message <- data_value(data, :message),
         true <- adapter_message?(message),
         false <- agent_message?(message),
         false <- assistant_echo?(message),
         false <- ignored_adapter_sender?(message),
         %Room{} = room <- Repo.get(Room, data_value(data, :room_id)) do
      settings = Agents.room_settings(room)
      settings["auto_reply_adapter_messages"] || trigger_text?(message_text(message))
    else
      _other -> false
    end
  rescue
    exception ->
      Logger.warning("Room Assistant auto-reply check failed: #{Exception.message(exception)}")
      false
  end

  defp reply_to_message(data) do
    with %Message{} = source_message <- data_value(data, :message),
         %Room{} = room <- Repo.get(Room, data_value(data, :room_id)),
         %User{} = user <- Repo.get(User, room.user_id),
         scope <- Scope.for_user(user),
         {:ok, _agent_pid} <- Agents.ensure_started(@agent_id),
         {:ok, assistant} <- Participants.ensure_room_assistant_participant(),
         {:ok, messages} <- Messaging.list_messages(to_string(room.id), limit: 20),
         settings <- Agents.room_settings(room),
         bridges <- Chat.list_room_bridges_for_room(scope, room.id),
         {:ok, reply} <-
           Agents.compose_room_reply(%{
             room: room,
             participants: Participants.list_for_room(room, user),
             bridges: bridges,
             messages: messages,
             intent: "adapter_auto_reply",
             mode: settings["agent_mode"]
           }),
         {:ok, reply_message} <- save_reply(room, assistant, source_message, reply) do
      _ = Participants.add_message_to_room_server(room, reply_message)

      delivery_result =
        if settings["relay_agent_replies"] do
          Messaging.route_outbound(to_string(room.id), reply.body)
        else
          :agent_local_only
        end

      Logger.info(
        "Room Assistant auto-replied in room #{room.id} to #{source_message.id}: #{inspect(delivery_result)}"
      )
    else
      nil ->
        :ok

      {:error, reason} ->
        Logger.warning("Room Assistant auto-reply failed: #{inspect(reason)}")

      other ->
        Logger.warning("Room Assistant auto-reply skipped: #{inspect(other)}")
    end
  rescue
    exception ->
      Logger.warning("Room Assistant auto-reply crashed: #{Exception.message(exception)}")
  catch
    kind, reason ->
      Logger.warning("Room Assistant auto-reply crashed: #{inspect({kind, reason})}")
  end

  defp save_reply(room, assistant, source_message, reply) do
    metadata = source_message.metadata || %{}

    Messaging.save_message(%{
      room_id: to_string(room.id),
      sender_id: assistant.id,
      role: :assistant,
      content: [%{type: :text, text: reply.body}],
      status: :sent,
      metadata: %{
        "author" => Participants.participant_name(assistant),
        "participant_id" => assistant.id,
        "source" => "agent",
        "agent_mode" => to_string(reply.mode),
        "intent" => reply.intent,
        "relay_agent_replies" => Agents.room_settings(room)["relay_agent_replies"],
        "in_reply_to_message_id" => source_message.id,
        "source_channel" => metadata_value(metadata, :channel),
        "source_bridge_id" => metadata_value(metadata, :bridge_id)
      }
    })
  end

  defp adapter_message?(%Message{metadata: metadata}) when is_map(metadata) do
    present?(metadata_value(metadata, :channel)) and
      present?(metadata_value(metadata, :bridge_id))
  end

  defp adapter_message?(_message), do: false

  defp agent_message?(%Message{sender_id: @agent_id}), do: true

  defp agent_message?(%Message{metadata: metadata}) when is_map(metadata) do
    metadata_value(metadata, :source) == "agent"
  end

  defp agent_message?(_message), do: false

  defp assistant_echo?(message) do
    message
    |> message_text()
    |> String.downcase()
    |> String.trim_leading()
    |> String.starts_with?("room assistant:")
  end

  defp ignored_adapter_sender?(%Message{metadata: metadata} = message) when is_map(metadata) do
    bridge_id = metadata_value(metadata, :bridge_id)
    channel = metadata_value(metadata, :channel)

    with %Bridge{} = bridge <- bridge_for_runtime_id(bridge_id),
         sender_id when is_binary(sender_id) <- sender_external_id(message, channel) do
      sender_id in ignored_external_user_ids(bridge.config || %{})
    else
      _other -> false
    end
  end

  defp ignored_adapter_sender?(_message), do: false

  defp bridge_for_runtime_id("ui_bridge:" <> id) do
    case Integer.parse(id) do
      {bridge_id, ""} -> Repo.get(Bridge, bridge_id)
      _other -> nil
    end
  end

  defp bridge_for_runtime_id(_bridge_id), do: nil

  defp sender_external_id(%Message{sender_id: sender_id}, channel) when is_binary(sender_id) do
    with {:ok, participant} <- Messaging.get_participant(sender_id) do
      metadata_value(participant.external_ids || %{}, channel)
    else
      _other -> nil
    end
  end

  defp sender_external_id(_message, _channel), do: nil

  defp ignored_external_user_ids(config) when is_map(config) do
    config_values(config, "ignore_external_user_ids") ++
      config_values(config, "ignore_bot_user_ids") ++
      env_config_values(config, "bot_user_id_env")
  end

  defp ignored_external_user_ids(_config), do: []

  defp config_values(config, key) do
    config
    |> metadata_value(key)
    |> list_values()
  end

  defp env_config_values(config, key) do
    config
    |> metadata_value(key)
    |> case do
      env_key when is_binary(env_key) ->
        env_key
        |> System.get_env()
        |> list_values()

      _other ->
        []
    end
  end

  defp list_values(values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp list_values(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp list_values(_value), do: []

  defp trigger_text?(text), do: Regex.match?(@trigger_pattern, text || "")

  defp message_id(%Message{id: id}) when is_binary(id), do: id
  defp message_id(_message), do: nil

  defp message_text(%Message{content: content}) when is_list(content) do
    Enum.find_value(content, "", fn
      %{type: :text, text: text} when is_binary(text) -> text
      %{"type" => "text", "text" => text} when is_binary(text) -> text
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      text when is_binary(text) -> text
      _part -> nil
    end)
  end

  defp message_text(%Message{content: content}) when is_binary(content), do: content
  defp message_text(_message), do: ""

  defp metadata_value(metadata, key) when is_map(metadata) and is_atom(key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp metadata_value(metadata, key) when is_map(metadata) and is_binary(key) do
    Map.get(metadata, key) || Map.get(metadata, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(metadata, key)
  end

  defp metadata_value(_metadata, _key), do: nil

  defp data_value(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, Atom.to_string(key))
  end

  defp data_value(_data, _key), do: nil

  defp present?(value) when value in [nil, ""], do: false
  defp present?(_value), do: true

  defp remember(state, message_id) do
    seen =
      state.seen
      |> MapSet.put(message_id)
      |> trim_seen()

    %{state | seen: seen}
  end

  defp trim_seen(seen) do
    if MapSet.size(seen) > 500 do
      seen
      |> MapSet.to_list()
      |> Enum.take(-400)
      |> MapSet.new()
    else
      seen
    end
  end
end
