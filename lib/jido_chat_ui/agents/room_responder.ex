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
         body <-
           reply_body(
             room,
             source_message,
             messages,
             Chat.list_room_bridges_for_room(scope, room.id)
           ),
         {:ok, reply_message} <- save_reply(room, assistant, source_message, body) do
      _ = Participants.add_message_to_room_server(room, reply_message)

      delivery_result =
        if Agents.room_settings(room)["relay_agent_replies"] do
          Messaging.route_outbound(to_string(room.id), body)
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

  defp save_reply(room, assistant, source_message, body) do
    metadata = source_message.metadata || %{}

    Messaging.save_message(%{
      room_id: to_string(room.id),
      sender_id: assistant.id,
      role: :assistant,
      content: [%{type: :text, text: body}],
      status: :sent,
      metadata: %{
        "author" => Participants.participant_name(assistant),
        "participant_id" => assistant.id,
        "source" => "agent",
        "agent_mode" => "auto_reply",
        "intent" => "adapter_auto_reply",
        "relay_agent_replies" => Agents.room_settings(room)["relay_agent_replies"],
        "in_reply_to_message_id" => source_message.id,
        "source_channel" => metadata_value(metadata, :channel),
        "source_bridge_id" => metadata_value(metadata, :bridge_id)
      }
    })
  end

  defp reply_body(room, source_message, messages, bridges) do
    source = source_message.metadata || %{}
    source_channel = source |> metadata_value(:channel) |> to_string()
    source_text = source_message |> message_text() |> one_line() |> String.slice(0, 180)
    bridge_count = Enum.count(bridges, &(&1.status == "active"))

    [
      "Room Assistant:",
      "I received your #{source_channel} message in #{room.name}: \"#{source_text}\".",
      "It came through the adapter bridge, was persisted by jido_messaging, and is now being relayed back through the active bridge.",
      "#{length(messages)} recent messages are visible to the room runtime; #{bridge_count} bridge(s) are active."
    ]
    |> Enum.join(" ")
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

  defp one_line(text) do
    text
    |> to_string()
    |> String.replace(~r/\\s+/, " ")
    |> String.trim()
  end

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
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
