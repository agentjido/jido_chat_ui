defmodule JidoChatUI.Messaging.Persistence.Postgres do
  @moduledoc """
  Postgres persistence adapter for the local `JidoChatUI.Messaging` runtime.

  The adapter stores canonical `jido_messaging` structs as terms so the UI
  exercises the same persistence contract as adapter ingress, outbound routing,
  room binding, and control-plane code. Narrow indexed columns are kept beside
  the serialized structs for the lookups that `Jido.Messaging.Persistence`
  requires.
  """

  @behaviour Jido.Messaging.Persistence
  @behaviour Jido.Messaging.Directory

  import Ecto.Query

  alias Jido.Chat.{Participant, Room}
  alias Jido.Messaging.{BridgeConfig, Message, RoomBinding, RoutingPolicy, Thread}

  defstruct [:repo]

  @rooms "jido_messaging_rooms"
  @participants "jido_messaging_participants"
  @threads "jido_messaging_threads"
  @messages "jido_messaging_messages"
  @room_bindings "jido_messaging_room_bindings"
  @participant_bindings "jido_messaging_participant_bindings"
  @onboarding "jido_messaging_onboarding_flows"
  @bridge_configs "jido_messaging_bridge_configs"
  @routing_policies "jido_messaging_routing_policies"

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{repo: Keyword.get(opts, :repo, JidoChatUI.Repo)}}
  end

  @impl true
  def save_room(state, %Room{} = room) do
    upsert_by_id(state, @rooms, room.id, room)
  end

  @impl true
  def get_room(state, room_id) do
    fetch_by(state, @rooms, :id, to_string(room_id))
  end

  @impl true
  def delete_room(state, room_id) do
    room_id = to_string(room_id)

    delete_all_by(state, @messages, :room_id, room_id)
    delete_all_by(state, @threads, :room_id, room_id)
    delete_all_by(state, @room_bindings, :room_id, room_id)
    delete_all_by(state, @rooms, :id, room_id)

    :ok
  end

  @impl true
  def list_rooms(state, opts \\ []) do
    {:ok, list_data(state, @rooms, opts)}
  end

  @impl true
  def save_participant(state, %Participant{} = participant) do
    upsert_by_id(state, @participants, participant.id, participant)
  end

  @impl true
  def get_participant(state, participant_id) do
    fetch_by(state, @participants, :id, to_string(participant_id))
  end

  @impl true
  def delete_participant(state, participant_id) do
    participant_id = to_string(participant_id)

    delete_all_by(state, @participant_bindings, :participant_id, participant_id)
    delete_all_by(state, @participants, :id, participant_id)

    :ok
  end

  @impl true
  def save_message(state, %Message{} = message) do
    extra = %{
      room_id: message.room_id,
      thread_id: message.thread_id,
      external_id: message.external_id,
      channel: normalize_or_nil(metadata_value(message.metadata, :channel)),
      bridge_id: normalize_or_nil(metadata_value(message.metadata, :bridge_id)),
      message_inserted_at: message.inserted_at || now()
    }

    upsert_by_id(state, @messages, message.id, message, extra)
  end

  @impl true
  def get_message(state, message_id) do
    fetch_by(state, @messages, :id, to_string(message_id))
  end

  @impl true
  def get_messages(state, room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    thread_id = Keyword.get(opts, :thread_id)

    query =
      if is_binary(thread_id) and thread_id != "" do
        from(row in @messages,
          where: field(row, :thread_id) == ^thread_id,
          order_by: [desc: field(row, :message_inserted_at)],
          limit: ^limit,
          select: field(row, :data)
        )
      else
        room_id = to_string(room_id)

        from(row in @messages,
          where: field(row, :room_id) == ^room_id,
          order_by: [desc: field(row, :message_inserted_at)],
          limit: ^limit,
          select: field(row, :data)
        )
      end

    messages =
      state.repo.all(query)
      |> Enum.map(&decode/1)
      |> Enum.reverse()

    {:ok, messages}
  end

  @impl true
  def delete_message(state, message_id) do
    delete_all_by(state, @messages, :id, to_string(message_id))
    :ok
  end

  @impl true
  def save_thread(state, %Thread{} = thread) do
    extra = %{
      room_id: thread.room_id,
      external_thread_id: normalize_or_nil(thread.external_thread_id),
      root_message_id: normalize_or_nil(thread.root_message_id)
    }

    upsert_by_id(state, @threads, thread.id, thread, extra)
  end

  @impl true
  def get_thread(state, thread_id) do
    fetch_by(state, @threads, :id, to_string(thread_id))
  end

  @impl true
  def get_thread_by_external_id(_state, _room_id, nil), do: {:error, :not_found}

  def get_thread_by_external_id(state, room_id, external_thread_id) do
    room_id = to_string(room_id)
    external_thread_id = normalize_term(external_thread_id)

    query =
      from(row in @threads,
        where:
          field(row, :room_id) == ^room_id and
            field(row, :external_thread_id) == ^external_thread_id,
        limit: 1,
        select: field(row, :data)
      )

    fetch_one(state, query)
  end

  @impl true
  def get_thread_by_root_message(_state, _room_id, nil), do: {:error, :not_found}

  def get_thread_by_root_message(state, room_id, root_message_id) do
    room_id = to_string(room_id)
    root_message_id = to_string(root_message_id)

    query =
      from(row in @threads,
        where:
          field(row, :room_id) == ^room_id and
            field(row, :root_message_id) == ^root_message_id,
        limit: 1,
        select: field(row, :data)
      )

    fetch_one(state, query)
  end

  @impl true
  def list_threads(state, room_id, opts \\ []) do
    room_id = to_string(room_id)
    limit = Keyword.get(opts, :limit, 100)

    query =
      from(row in @threads,
        where: field(row, :room_id) == ^room_id,
        order_by: [asc: field(row, :inserted_at)],
        limit: ^limit,
        select: field(row, :data)
      )

    {:ok, state.repo.all(query) |> Enum.map(&decode/1)}
  end

  @impl true
  def get_or_create_room_by_external_binding(state, channel, bridge_id, external_id, attrs) do
    case get_room_by_external_binding(state, channel, bridge_id, external_id) do
      {:ok, _room} = ok ->
        ok

      {:error, :not_found} ->
        room = build_bound_room(channel, bridge_id, external_id, attrs)

        with {:ok, room} <- save_room(state, room),
             {:ok, _binding} <-
               create_room_binding(state, room.id, channel, bridge_id, external_id, %{}) do
          {:ok, room}
        end
    end
  end

  @impl true
  def get_or_create_participant_by_external_id(state, channel, external_id, attrs) do
    channel_key = normalize_term(channel)
    external_id = normalize_term(external_id)

    case participant_id_by_binding(state, channel_key, external_id) do
      {:ok, participant_id} ->
        get_participant(state, participant_id)

      {:error, :not_found} ->
        participant = build_bound_participant(channel, external_id, attrs)

        with {:ok, participant} <- save_participant(state, participant),
             :ok <- create_participant_binding(state, participant.id, channel_key, external_id) do
          {:ok, participant}
        end
    end
  end

  @impl true
  def get_message_by_external_id(_state, _channel, _bridge_id, nil), do: {:error, :not_found}

  def get_message_by_external_id(state, channel, bridge_id, external_id) do
    channel = normalize_term(channel)
    bridge_id = normalize_term(bridge_id)
    external_id = normalize_term(external_id)

    query =
      from(row in @messages,
        where:
          field(row, :channel) == ^channel and
            field(row, :bridge_id) == ^bridge_id and
            field(row, :external_id) == ^external_id,
        limit: 1,
        select: field(row, :data)
      )

    fetch_one(state, query)
  end

  @impl true
  def update_message_external_id(state, message_id, external_id) do
    with {:ok, %Message{} = message} <- get_message(state, message_id) do
      save_message(state, %{message | external_id: normalize_term(external_id), updated_at: now()})
    end
  end

  @impl true
  def get_room_by_external_binding(state, channel, bridge_id, external_id) do
    case room_binding_by_key(state, channel, bridge_id, external_id) do
      {:ok, %RoomBinding{room_id: room_id}} -> get_room(state, room_id)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @impl true
  def create_room_binding(state, room_id, channel, bridge_id, external_id, attrs) do
    room_id = to_string(room_id)

    case room_binding_by_key(state, channel, bridge_id, external_id) do
      {:ok, %RoomBinding{} = binding} ->
        update_room_binding(state, binding, room_id, attrs)

      {:error, :not_found} ->
        insert_room_binding(state, room_id, channel, bridge_id, external_id, attrs)
    end
  end

  @impl true
  def list_room_bindings(state, room_id) do
    room_id = to_string(room_id)

    query =
      from(row in @room_bindings,
        where: field(row, :room_id) == ^room_id,
        order_by: [asc: field(row, :inserted_at)],
        select: field(row, :data)
      )

    {:ok, state.repo.all(query) |> Enum.map(&decode/1)}
  end

  @impl true
  def delete_room_binding(state, binding_id) do
    query = from(row in @room_bindings, where: field(row, :id) == ^to_string(binding_id))

    case state.repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  @impl Jido.Messaging.Directory
  def lookup(state, target, query) when is_map(query) do
    directory_lookup(state, target, query, [])
  end

  @impl Jido.Messaging.Directory
  def search(state, target, query) when is_map(query) do
    directory_search(state, target, query, [])
  end

  @impl true
  def directory_lookup(state, target, query, opts \\ []) when is_map(query) do
    case directory_search(state, target, query, opts) do
      {:ok, [entry]} -> {:ok, entry}
      {:ok, []} -> {:error, :not_found}
      {:ok, matches} -> {:error, {:ambiguous, matches}}
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def directory_search(state, :participant, query, _opts) when is_map(query) do
    participants =
      list_data(state, @participants, [])
      |> Enum.filter(&participant_matches?(&1, query))
      |> Enum.sort_by(& &1.id)

    {:ok, participants}
  end

  def directory_search(state, :room, query, _opts) when is_map(query) do
    rooms =
      list_data(state, @rooms, [])
      |> Enum.filter(&room_matches?(state, &1, query))
      |> Enum.sort_by(& &1.id)

    {:ok, rooms}
  end

  def directory_search(_state, target, _query, _opts) do
    {:error, {:invalid_directory_target, target}}
  end

  @impl true
  def save_onboarding(state, onboarding_flow) when is_map(onboarding_flow) do
    onboarding_id = map_value(onboarding_flow, :onboarding_id)

    if is_binary(onboarding_id) and onboarding_id != "" do
      now = now()

      row = %{
        onboarding_id: onboarding_id,
        data: encode(onboarding_flow),
        inserted_at: now,
        updated_at: now
      }

      state.repo.insert_all(@onboarding, [row],
        on_conflict: {:replace, [:data, :updated_at]},
        conflict_target: [:onboarding_id]
      )

      {:ok, onboarding_flow}
    else
      {:error, :invalid_onboarding_id}
    end
  end

  @impl true
  def get_onboarding(state, onboarding_id) when is_binary(onboarding_id) do
    fetch_by(state, @onboarding, :onboarding_id, onboarding_id)
  end

  @impl true
  def save_bridge_config(state, %BridgeConfig{} = bridge_config) do
    extra = %{
      adapter_module: Atom.to_string(bridge_config.adapter_module),
      enabled: bridge_config.enabled
    }

    upsert_by_id(state, @bridge_configs, bridge_config.id, bridge_config, extra)
  end

  @impl true
  def get_bridge_config(state, bridge_id) when is_binary(bridge_id) do
    fetch_by(state, @bridge_configs, :id, bridge_id)
  end

  @impl true
  def list_bridge_configs(state, opts \\ []) do
    enabled_filter = Keyword.get(opts, :enabled)

    query =
      case enabled_filter do
        enabled when is_boolean(enabled) ->
          from(row in @bridge_configs,
            where: field(row, :enabled) == ^enabled,
            order_by: [asc: field(row, :id)],
            select: field(row, :data)
          )

        _ ->
          from(row in @bridge_configs,
            order_by: [asc: field(row, :id)],
            select: field(row, :data)
          )
      end

    {:ok, state.repo.all(query) |> Enum.map(&decode/1)}
  end

  @impl true
  def delete_bridge_config(state, bridge_id) when is_binary(bridge_id) do
    query = from(row in @bridge_configs, where: field(row, :id) == ^bridge_id)

    case state.repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  @impl true
  def save_routing_policy(state, %RoutingPolicy{} = routing_policy) do
    now = now()

    row = %{
      room_id: routing_policy.room_id,
      data: encode(routing_policy),
      inserted_at: now,
      updated_at: now
    }

    state.repo.insert_all(@routing_policies, [row],
      on_conflict: {:replace, [:data, :updated_at]},
      conflict_target: [:room_id]
    )

    {:ok, routing_policy}
  end

  @impl true
  def get_routing_policy(state, room_id) when is_binary(room_id) do
    fetch_by(state, @routing_policies, :room_id, room_id)
  end

  @impl true
  def delete_routing_policy(state, room_id) when is_binary(room_id) do
    query = from(row in @routing_policies, where: field(row, :room_id) == ^room_id)

    case state.repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  defp upsert_by_id(state, table, id, record, extra_columns \\ %{}) do
    now = now()

    row =
      %{id: to_string(id), data: encode(record), inserted_at: now, updated_at: now}
      |> Map.merge(extra_columns)

    replace_columns =
      [:data, :updated_at | Map.keys(extra_columns)]
      |> Enum.uniq()

    state.repo.insert_all(table, [row],
      on_conflict: {:replace, replace_columns},
      conflict_target: [:id]
    )

    {:ok, record}
  rescue
    exception -> {:error, exception}
  end

  defp fetch_by(state, table, field, value) do
    query =
      from(row in table,
        where: field(row, ^field) == ^value,
        limit: 1,
        select: field(row, :data)
      )

    fetch_one(state, query)
  end

  defp fetch_one(state, query) do
    case state.repo.one(query) do
      nil -> {:error, :not_found}
      data -> {:ok, decode(data)}
    end
  end

  defp list_data(state, table, opts) do
    limit = Keyword.get(opts, :limit, 100)

    query =
      from(row in table,
        order_by: [asc: field(row, :id)],
        limit: ^limit,
        select: field(row, :data)
      )

    state.repo.all(query) |> Enum.map(&decode/1)
  end

  defp delete_all_by(state, table, field, value) do
    query = from(row in table, where: field(row, ^field) == ^value)
    state.repo.delete_all(query)
  end

  defp room_binding_by_key(state, channel, bridge_id, external_id) do
    channel = normalize_term(channel)
    bridge_id = normalize_term(bridge_id)
    external_id = normalize_term(external_id)

    query =
      from(row in @room_bindings,
        where:
          field(row, :channel) == ^channel and
            field(row, :bridge_id) == ^bridge_id and
            field(row, :external_room_id) == ^external_id,
        limit: 1,
        select: field(row, :data)
      )

    fetch_one(state, query)
  end

  defp insert_room_binding(state, room_id, channel, bridge_id, external_id, attrs) do
    binding =
      RoomBinding.new(
        Map.merge(attrs, %{
          room_id: to_string(room_id),
          channel: channel_atom(channel),
          bridge_id: normalize_term(bridge_id),
          external_room_id: normalize_term(external_id)
        })
      )

    extra = %{
      room_id: binding.room_id,
      channel: normalize_term(binding.channel),
      bridge_id: binding.bridge_id,
      external_room_id: binding.external_room_id
    }

    upsert_by_id(state, @room_bindings, binding.id, binding, extra)
  rescue
    _exception ->
      room_binding_by_key(state, channel, bridge_id, external_id)
  end

  defp update_room_binding(state, %RoomBinding{} = binding, room_id, attrs) do
    binding = %{
      binding
      | room_id: room_id,
        direction: Map.get(attrs, :direction, Map.get(attrs, "direction", binding.direction)),
        enabled: Map.get(attrs, :enabled, Map.get(attrs, "enabled", binding.enabled))
    }

    extra = %{
      room_id: binding.room_id,
      channel: normalize_term(binding.channel),
      bridge_id: binding.bridge_id,
      external_room_id: binding.external_room_id
    }

    upsert_by_id(state, @room_bindings, binding.id, binding, extra)
  end

  defp participant_id_by_binding(state, channel, external_id) do
    query =
      from(row in @participant_bindings,
        where:
          field(row, :channel) == ^channel and
            field(row, :external_id) == ^external_id,
        limit: 1,
        select: field(row, :participant_id)
      )

    case state.repo.one(query) do
      nil -> {:error, :not_found}
      participant_id -> {:ok, participant_id}
    end
  end

  defp create_participant_binding(state, participant_id, channel, external_id) do
    now = now()

    row = %{
      id: "participant:#{channel}:#{external_id}",
      participant_id: to_string(participant_id),
      channel: channel,
      external_id: external_id,
      inserted_at: now,
      updated_at: now
    }

    state.repo.insert_all(@participant_bindings, [row],
      on_conflict: {:replace, [:participant_id, :updated_at]},
      conflict_target: [:channel, :external_id]
    )

    :ok
  end

  defp participant_matches?(participant, query) do
    id_matches?(participant.id, query) and
      name_matches?(participant_name(participant), query) and
      participant_external_id_matches?(participant, query)
  end

  defp room_matches?(state, room, query) do
    id_matches?(room.id, query) and
      name_matches?(room.name, query) and
      room_external_binding_matches?(state, room.id, query)
  end

  defp participant_external_id_matches?(participant, query) do
    channel = query_value(query, :channel)
    external_id = query_value(query, :external_id)

    cond do
      is_nil(channel) and is_nil(external_id) ->
        true

      is_nil(channel) or is_nil(external_id) ->
        false

      true ->
        expected_channel = normalize_term(channel)
        expected_external_id = normalize_term(external_id)

        participant.external_ids
        |> Enum.any?(fn {binding_channel, binding_external_id} ->
          normalize_term(binding_channel) == expected_channel and
            normalize_term(binding_external_id) == expected_external_id
        end)
    end
  end

  defp room_external_binding_matches?(state, room_id, query) do
    channel = query_value(query, :channel)
    bridge_id = query_value(query, :bridge_id)
    external_id = query_value(query, :external_id)

    cond do
      is_nil(channel) and is_nil(bridge_id) and is_nil(external_id) ->
        true

      is_nil(channel) or is_nil(bridge_id) or is_nil(external_id) ->
        false

      true ->
        case room_binding_by_key(state, channel, bridge_id, external_id) do
          {:ok, %RoomBinding{room_id: ^room_id}} -> true
          _ -> false
        end
    end
  end

  defp id_matches?(id, query) do
    case query_value(query, :id) do
      nil -> true
      expected_id -> normalize_term(id) == normalize_term(expected_id)
    end
  end

  defp name_matches?(name, query) do
    case query_value(query, :name) do
      nil -> true
      expected_name -> contains_ci?(name, expected_name)
    end
  end

  defp contains_ci?(value, expected) when is_binary(value) do
    String.contains?(String.downcase(value), String.downcase(to_string(expected)))
  end

  defp contains_ci?(_value, _expected), do: false

  defp participant_name(participant) do
    map_value(participant.identity, :name)
  end

  defp build_bound_room(channel, bridge_id, external_id, attrs) do
    Room.new(
      Map.merge(attrs, %{
        external_bindings: %{
          channel_atom(channel) => %{normalize_term(bridge_id) => normalize_term(external_id)}
        }
      })
    )
  end

  defp build_bound_participant(channel, external_id, attrs) do
    Participant.new(
      Map.merge(attrs, %{
        external_ids: %{channel_atom(channel) => normalize_term(external_id)}
      })
    )
  end

  defp metadata_value(metadata, key) when is_map(metadata), do: map_value(metadata, key)
  defp metadata_value(_metadata, _key), do: nil

  defp map_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp query_value(query, key), do: map_value(query, key)

  defp normalize_or_nil(nil), do: nil
  defp normalize_or_nil(""), do: nil
  defp normalize_or_nil(value), do: normalize_term(value)

  defp normalize_term(value) when is_binary(value), do: value
  defp normalize_term(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_term(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_term(value), do: to_string(value)

  defp channel_atom(value) when is_atom(value), do: value
  defp channel_atom("discord"), do: :discord
  defp channel_atom("github"), do: :github
  defp channel_atom("mattermost"), do: :mattermost
  defp channel_atom("signal"), do: :signal
  defp channel_atom("slack"), do: :slack
  defp channel_atom("telegram"), do: :telegram
  defp channel_atom("x"), do: :x

  defp channel_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> String.to_atom(value)
  end

  defp encode(term), do: :erlang.term_to_binary(term)
  defp decode(binary), do: :erlang.binary_to_term(binary)

  defp now do
    DateTime.utc_now(:microsecond)
  end
end
