defmodule JidoChatUI.RoomTimeline do
  @moduledoc """
  Observable room timeline used by the developer UI.

  Timeline state is UI-local for Filament subscriptions, but it hydrates from
  `JidoChatUI.Messaging` so room messages are persisted through the canonical
  `jido_messaging` runtime.
  """

  use Filament.Observable.GenServer

  alias Jido.Messaging.Message
  alias JidoChatUI.Messaging

  @registry JidoChatUI.RoomTimeline.Registry
  @supervisor JidoChatUI.RoomTimeline.Supervisor

  def via_room(room_id), do: {:via, Registry, {@registry, room_key(room_id)}}

  def ensure_started(room_id, room_name \\ nil) do
    child_spec = {__MODULE__, room_id: room_id, room_name: room_name, name: via_room(room_id)}

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def disconnected_state(room_id, room_name \\ nil) do
    initial_state(room_id, room_name)
  end

  def post_message(server, attrs) when is_pid(server) do
    GenServer.call(server, {:post_message, attrs})
  end

  def post_message(room_id, attrs) do
    GenServer.call(via_room(room_id), {:post_message, attrs})
  end

  def from_messaging_message(%Message{} = message) do
    metadata = message.metadata || %{}

    build_message(%{
      id: message.id,
      author:
        metadata_value(metadata, :author) ||
          metadata_value(metadata, :display_name) ||
          metadata_value(metadata, :username) ||
          message.sender_id,
      body: text_content(message.content),
      source: metadata_value(metadata, :source) || metadata_value(metadata, :channel) || "ui",
      status: timeline_status(message.status, metadata),
      at: message.inserted_at || DateTime.utc_now(:second),
      metadata: metadata
    })
  end

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    room_id = Keyword.fetch!(opts, :room_id)
    room_name = Keyword.get(opts, :room_name)

    GenServer.start_link(__MODULE__, initial_state(room_id, room_name), name: name)
  end

  @impl GenServer
  def init(state) do
    send(self(), :subscribe_to_messaging_signals)
    {:ok, state}
  end

  @impl Filament.Observable
  def handle_subscribe(_subscriber, state), do: {:ok, state, state}

  @impl GenServer
  def handle_call({:post_message, attrs}, _from, state) do
    message = build_message(attrs)

    state = upsert_message(state, message)

    notify_observers(state)

    {:reply, {:ok, message}, state}
  end

  @impl GenServer
  def handle_info(:subscribe_to_messaging_signals, state) do
    bus_name = Module.concat(Messaging, SignalBus)

    case Jido.Signal.Bus.subscribe(bus_name, "jido.messaging.room.message_added") do
      {:ok, _subscription_id} ->
        {:noreply, state}

      {:error, _reason} ->
        Process.send_after(self(), :subscribe_to_messaging_signals, 250)
        {:noreply, state}
    end
  end

  def handle_info({:signal, %{type: "jido.messaging.room.message_added", data: data}}, state) do
    if same_room?(data_value(data, :room_id), state.room_id) do
      state =
        data
        |> data_value(:message)
        |> maybe_append_messaging_message(state)

      notify_observers(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp initial_state(room_id, room_name) do
    %{
      room_id: room_id,
      room_name: room_name || "Room #{room_id}",
      messages: [system_ready_message()] ++ persisted_messages(room_id)
    }
  end

  defp system_ready_message do
    %{
      id: "system-ready",
      author: "System",
      body: "Room is ready. Add bridges, then send a message from the composer or an adapter.",
      source: "system",
      status: "ready",
      at: DateTime.utc_now(:second),
      metadata: %{}
    }
  end

  defp persisted_messages(room_id) do
    case Messaging.list_messages(to_string(room_id), limit: 100) do
      {:ok, messages} -> Enum.map(messages, &from_messaging_message/1)
      {:error, _reason} -> []
    end
  rescue
    _exception -> []
  catch
    :exit, _reason -> []
  end

  defp build_message(attrs) do
    attrs = stringify_keys(attrs)

    %{
      id: Map.get(attrs, "id") || next_id(),
      author: clean(Map.get(attrs, "author"), "Unknown"),
      body: clean(Map.get(attrs, "body"), ""),
      source: clean(Map.get(attrs, "source"), "ui"),
      status: clean(Map.get(attrs, "status"), "queued"),
      at: Map.get(attrs, "at") || DateTime.utc_now(:second),
      metadata: Map.get(attrs, "metadata") || %{}
    }
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp clean(nil, default), do: default
  defp clean(value, _default) when is_binary(value), do: String.trim(value)
  defp clean(value, _default), do: to_string(value)

  defp text_content(content) when is_list(content) do
    Enum.find_value(content, "", fn
      %{type: :text, text: text} -> text
      %{"type" => "text", "text" => text} -> text
      %{text: text} -> text
      %{"text" => text} -> text
      text when is_binary(text) -> text
      _part -> nil
    end)
  end

  defp text_content(content) when is_binary(content), do: content
  defp text_content(_content), do: ""

  defp metadata_value(metadata, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp timeline_status(:delivered, metadata) do
    case metadata_value(metadata, :delivered) do
      count when is_integer(count) and count > 0 -> "delivered:#{count}"
      count when is_binary(count) and count != "" -> "delivered:#{count}"
      _other -> "delivered"
    end
  end

  defp timeline_status(status, _metadata), do: status || :sent

  defp data_value(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, Atom.to_string(key))
  end

  defp data_value(_data, _key), do: nil

  defp same_room?(left, right), do: to_string(left) == to_string(right)

  defp maybe_append_messaging_message(%Message{} = message, state) do
    upsert_message(state, from_messaging_message(message))
  end

  defp maybe_append_messaging_message(_message, state), do: state

  defp upsert_message(state, message) do
    if Enum.any?(state.messages, &(&1.id == message.id)) do
      %{state | messages: Enum.map(state.messages, &replace_message(&1, message))}
    else
      %{state | messages: state.messages ++ [message]}
    end
  end

  defp replace_message(%{id: id}, %{id: id} = message), do: message
  defp replace_message(existing, _message), do: existing

  defp next_id do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
  end

  defp room_key(room_id), do: to_string(room_id)
end
