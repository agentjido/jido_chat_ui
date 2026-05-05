defmodule JidoChatUI.Messaging.Participants do
  @moduledoc """
  Helpers for representing UI users, external users, and Jidoka agents as
  `jido_messaging` participants.
  """

  alias Jido.Messaging.RoomServer
  alias JidoChatUI.Accounts.User
  alias JidoChatUI.Chat.Room
  alias JidoChatUI.{Agents, Messaging}

  @room_assistant_id "room_assistant"

  def room_assistant_id, do: @room_assistant_id

  def ui_participant_id(%User{id: id}), do: "ui:user:#{id}"
  def ui_participant_id(%{id: id}), do: "ui:user:#{id}"

  def ensure_user_participant(%User{} = user) do
    Messaging.get_or_create_participant_by_external_id(:ui, user.id, %{
      id: ui_participant_id(user),
      type: :human,
      identity: %{name: user.email, email: user.email},
      presence: :online,
      capabilities: [:text],
      metadata: %{"source" => "phoenix"}
    })
  end

  def ensure_room_assistant_participant do
    Messaging.get_or_create_participant_by_external_id(:jidoka, @room_assistant_id, %{
      id: @room_assistant_id,
      type: :agent,
      identity: %{name: "Room Assistant"},
      presence: room_assistant_presence(),
      capabilities: [:text],
      metadata: %{
        "source" => "jidoka",
        "agent_module" => inspect(JidoChatUI.Agents.RoomAssistant)
      }
    })
  end

  def ensure_room_defaults(%Room{} = room, %User{} = user) do
    with {:ok, user_participant} <- ensure_user_participant(user),
         _agent_start <- Agents.ensure_started(@room_assistant_id),
         {:ok, assistant_participant} <- ensure_room_assistant_participant(),
         {:ok, room_server} <- ensure_room_server(room) do
      :ok = RoomServer.add_participant(room_server, user_participant)
      :ok = RoomServer.add_participant(room_server, assistant_participant)
      _ = register_room_assistant(room.id)

      {:ok, [user_participant, assistant_participant]}
    end
  end

  def list_for_room(%Room{} = room, %User{} = user) do
    default_participants =
      [ui_participant_id(user), @room_assistant_id]
      |> Enum.flat_map(&fetch_participant/1)

    runtime_participants = runtime_participants(room.id)
    message_participants = message_participants(room.id)

    (default_participants ++ runtime_participants ++ message_participants)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(&participant_sort_key/1)
  end

  def add_message_to_room_server(%Room{} = room, message) do
    with {:ok, room_server} <- ensure_room_server(room) do
      RoomServer.add_message(room_server, message)
    end
  end

  def participant_name(participant) do
    participant.identity
    |> map_value(:name)
    |> case do
      nil -> participant.id
      "" -> participant.id
      name -> name
    end
  end

  def participant_source(participant) do
    participant.metadata
    |> map_value(:source)
    |> case do
      nil -> external_source(participant.external_ids)
      source -> source
    end
  end

  defp ensure_room_server(%Room{id: id}) do
    case Messaging.get_room(to_string(id)) do
      {:ok, messaging_room} -> Messaging.get_or_start_room_server(messaging_room)
      {:error, _reason} = error -> error
    end
  end

  defp register_room_assistant(room_id) do
    Messaging.register_agent(to_string(room_id), %{
      agent_id: @room_assistant_id,
      name: "Room Assistant",
      mention_handles: ["room_assistant", "assistant", "jido"],
      trigger: :manual_mention
    })
  rescue
    exception -> {:error, exception}
  catch
    :exit, reason -> {:error, reason}
  end

  defp runtime_participants(room_id) do
    case Messaging.whereis_room_server(to_string(room_id)) do
      pid when is_pid(pid) -> RoomServer.get_participants(pid)
      nil -> []
    end
  rescue
    _exception -> []
  catch
    :exit, _reason -> []
  end

  defp message_participants(room_id) do
    case Messaging.list_messages(to_string(room_id), limit: 100) do
      {:ok, messages} ->
        messages
        |> Enum.map(& &1.sender_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.flat_map(&fetch_participant/1)

      {:error, _reason} ->
        []
    end
  rescue
    _exception -> []
  catch
    :exit, _reason -> []
  end

  defp fetch_participant(participant_id) do
    case Messaging.get_participant(to_string(participant_id)) do
      {:ok, participant} -> [participant]
      {:error, _reason} -> []
    end
  end

  defp room_assistant_presence do
    if match?(pid when is_pid(pid), Jidoka.whereis(@room_assistant_id)) do
      :online
    else
      :away
    end
  rescue
    _exception -> :away
  catch
    :exit, _reason -> :away
  end

  defp participant_sort_key(participant) do
    {type_rank(participant.type), participant_name(participant)}
  end

  defp type_rank(:human), do: 0
  defp type_rank(:agent), do: 1
  defp type_rank(:system), do: 2
  defp type_rank(_type), do: 3

  defp external_source(external_ids) when is_map(external_ids) and map_size(external_ids) > 0 do
    external_ids
    |> Map.keys()
    |> List.first()
    |> to_string()
  end

  defp external_source(_external_ids), do: "local"

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_map, _key), do: nil
end
