defmodule JidoChatUI.RoomTimeline do
  @moduledoc """
  In-memory observable room timeline used by the developer UI.

  This is deliberately UI-local for the spike. The next integration step is to
  hydrate this state from `jido_messaging` persistence and delivery events.
  """

  use Filament.Observable.GenServer

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

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    room_id = Keyword.fetch!(opts, :room_id)
    room_name = Keyword.get(opts, :room_name)

    GenServer.start_link(__MODULE__, initial_state(room_id, room_name), name: name)
  end

  @impl GenServer
  def init(state), do: {:ok, state}

  @impl Filament.Observable
  def handle_subscribe(_request, _subscriber, state), do: {:ok, state, state}

  @impl GenServer
  def handle_call({:post_message, attrs}, _from, state) do
    message = build_message(attrs)
    state = %{state | messages: state.messages ++ [message]}
    notify_observers(state)

    {:reply, {:ok, message}, state}
  end

  defp initial_state(room_id, room_name) do
    %{
      room_id: room_id,
      room_name: room_name || "Room #{room_id}",
      messages: [
        %{
          id: "system-ready",
          author: "System",
          body:
            "Room is ready. Add bridges, then send a message from the composer or an adapter.",
          source: "system",
          status: "ready",
          at: DateTime.utc_now(:second),
          metadata: %{}
        }
      ]
    }
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

  defp next_id do
    System.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
  end

  defp room_key(room_id), do: to_string(room_id)
end
