defmodule JidoChatUI.Agents do
  @moduledoc """
  Jidoka agents available to attach to rooms.
  """

  @room_assistant %{
    id: "room_assistant",
    name: "Room Assistant",
    module: JidoChatUI.Agents.RoomAssistant,
    response_policy: "manual mention",
    description: "A concise helper for testing Jido chat adapters from a room."
  }

  @default_room_settings %{
    "agent_mode" => "deterministic",
    "relay_agent_replies" => false,
    "auto_reply_adapter_messages" => false
  }

  def list_agents, do: [agent_status(@room_assistant)]
  def get_agent("room_assistant"), do: agent_status(@room_assistant)
  def get_agent(_id), do: nil

  def room_settings(room_or_metadata)

  def room_settings(%{metadata: metadata}), do: room_settings(metadata)

  def room_settings(metadata) when is_map(metadata) do
    agent_settings =
      metadata
      |> map_value(:agent)
      |> case do
        settings when is_map(settings) -> settings
        _settings -> %{}
      end

    @default_room_settings
    |> Map.merge(stringify_keys(agent_settings))
    |> normalize_room_settings()
  end

  def room_settings(_metadata), do: @default_room_settings

  def put_room_settings(metadata, attrs) when is_map(attrs) do
    settings =
      metadata
      |> room_settings()
      |> Map.merge(stringify_keys(attrs))
      |> normalize_room_settings()

    metadata
    |> then(&(&1 || %{}))
    |> Map.put("agent", settings)
  end

  def ensure_started(id \\ "room_assistant")

  def ensure_started("room_assistant") do
    agent = @room_assistant

    cond do
      !Code.ensure_loaded?(agent.module) ->
        {:error, :agent_module_unavailable}

      pid = Jidoka.whereis(agent.id) ->
        {:ok, pid}

      true ->
        normalize_start_result(agent.module.start_link(id: agent.id))
    end
  rescue
    exception -> {:error, exception}
  catch
    :exit, reason -> {:error, reason}
  end

  def ensure_started(_id), do: {:error, :unknown_agent}

  def compose_room_reply(attrs) when is_map(attrs) do
    intent = normalize_intent(Map.get(attrs, :intent) || Map.get(attrs, "intent"))
    room = Map.fetch!(attrs, :room)
    participants = Map.get(attrs, :participants, [])
    bridges = Map.get(attrs, :bridges, [])
    messages = Map.get(attrs, :messages, [])
    mode = normalize_agent_mode(Map.get(attrs, :mode) || Map.get(attrs, "mode"))

    case mode do
      "llm" -> llm_reply(room, participants, bridges, messages, intent)
      _mode -> deterministic_reply(room, participants, bridges, messages, intent)
    end
  end

  defp agent_status(agent) do
    agent
    |> Map.put(:loaded?, Code.ensure_loaded?(agent.module))
    |> Map.put(:running?, running?(agent.id))
  end

  defp running?(id) do
    match?(pid when is_pid(pid), Jidoka.whereis(id))
  rescue
    _exception -> false
  catch
    :exit, _reason -> false
  end

  defp normalize_start_result({:ok, pid}), do: {:ok, pid}
  defp normalize_start_result({:error, {:already_started, pid}}), do: {:ok, pid}
  defp normalize_start_result({:error, {:already_registered, pid}}), do: {:ok, pid}
  defp normalize_start_result({:error, reason}), do: {:error, reason}
  defp normalize_start_result(other), do: other

  defp normalize_intent(nil), do: "summary"
  defp normalize_intent(intent), do: intent |> to_string() |> String.trim()

  defp normalize_agent_mode("llm"), do: "llm"
  defp normalize_agent_mode(:llm), do: "llm"
  defp normalize_agent_mode(_mode), do: "deterministic"

  defp normalize_room_settings(settings) do
    %{
      "agent_mode" => normalize_agent_mode(Map.get(settings, "agent_mode")),
      "relay_agent_replies" => truthy?(Map.get(settings, "relay_agent_replies")),
      "auto_reply_adapter_messages" => truthy?(Map.get(settings, "auto_reply_adapter_messages"))
    }
  end

  defp deterministic_reply(room, participants, bridges, messages, intent) do
    body =
      case intent do
        "debug" -> debug_reply(room, participants, bridges, messages)
        "next_test" -> next_test_reply(room, participants, bridges, messages)
        _intent -> summary_reply(room, participants, bridges, messages)
      end

    {:ok,
     %{
       body: body,
       intent: intent,
       mode: :deterministic
     }}
  end

  defp llm_reply(room, participants, bridges, messages, intent) do
    if llm_configured?() do
      prompt = llm_prompt(room, participants, bridges, messages, intent)

      case Jidoka.chat(@room_assistant.id, prompt,
             conversation: "room:#{room.id}",
             timeout: 30_000
           ) do
        {:ok, response} ->
          {:ok,
           %{
             body: response_text(response),
             intent: intent,
             mode: :llm
           }}

        {:error, reason} ->
          {:ok,
           %{
             body:
               "LLM mode is enabled, but the Room Assistant request failed: #{inspect(reason)}",
             intent: intent,
             mode: :llm_error
           }}
      end
    else
      {:ok,
       %{
         body:
           "LLM mode is selected, but no model provider key is configured. Add ANTHROPIC_API_KEY or OPENAI_API_KEY, then retry this assistant action.",
         intent: intent,
         mode: :llm_unavailable
       }}
    end
  end

  defp llm_configured? do
    present_env?("ANTHROPIC_API_KEY") or present_env?("OPENAI_API_KEY")
  end

  defp present_env?(key) do
    key
    |> System.get_env()
    |> case do
      nil -> false
      value -> String.trim(value) != ""
    end
  end

  defp llm_prompt(room, participants, bridges, messages, intent) do
    """
    You are the Room Assistant inside Jido Chat UI.
    Intent: #{intent}
    Room: #{room.name}
    Active bridges: #{active_bridge_count(bridges)}
    Participants: #{participants_summary(participants)}

    Recent messages:
    #{messages_summary(messages)}

    Reply concisely. Focus on helping a developer validate this room, bridges, participants, persistence, and next test step.
    """
  end

  defp response_text(response) when is_binary(response), do: String.trim(response)
  defp response_text(%{result: result}) when is_binary(result), do: String.trim(result)
  defp response_text(%{text: text}) when is_binary(text), do: String.trim(text)
  defp response_text(response), do: response |> inspect() |> String.slice(0, 2_000)

  defp participants_summary(participants) do
    participants
    |> Enum.map(fn participant -> "#{participant_source(participant)}:#{participant.id}" end)
    |> Enum.take(20)
    |> Enum.join(", ")
    |> blank_default("none")
  end

  defp messages_summary(messages) do
    messages
    |> Enum.take(10)
    |> Enum.map(fn message ->
      "- #{message.sender_id}: #{String.slice(message_text(message), 0, 220)}"
    end)
    |> Enum.join("\n")
    |> blank_default("none")
  end

  defp summary_reply(room, participants, bridges, messages) do
    latest = latest_line(messages)

    [
      "Room check: #{room.name} has #{length(participants)} participants and #{active_bridge_count(bridges)} active bridges.",
      persisted_line(messages),
      latest
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp debug_reply(room, participants, bridges, messages) do
    sources =
      participants
      |> Enum.map(&participant_source/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join(", ")

    bridge_names =
      bridges
      |> Enum.map(&bridge_adapter/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join(", ")

    [
      "Debug view for #{room.name}:",
      "#{length(messages)} persisted messages.",
      "Participant sources: #{blank_default(sources, "none yet")}.",
      "Active bridge adapters: #{blank_default(bridge_names, "none")}."
    ]
    |> Enum.join(" ")
  end

  defp next_test_reply(room, participants, bridges, messages) do
    adapter_sources =
      participants
      |> Enum.map(&participant_source/1)
      |> Enum.reject(&(&1 in ["phoenix", "jidoka", "local"]))
      |> Enum.uniq()

    cond do
      active_bridge_count(bridges) == 0 ->
        "Next for #{room.name}: add one bridge, send one adapter message, then confirm it appears here as a persisted adapter message."

      adapter_sources == [] ->
        "Next for #{room.name}: send a message from a connected client so the room captures an external participant."

      messages == [] ->
        "Next for #{room.name}: send one UI message, then one adapter message, and compare delivery status."

      true ->
        "Next for #{room.name}: test a UI reply, an adapter reply, and one failure path by disabling a bridge."
    end
  end

  defp persisted_line([]), do: "No persisted messages yet."

  defp persisted_line(messages),
    do: "#{length(messages)} messages are persisted through jido_messaging."

  defp latest_line([]), do: nil

  defp latest_line(messages) do
    case List.first(messages) do
      nil ->
        nil

      message ->
        text = message_text(message)

        if text == "" do
          nil
        else
          "Latest: #{String.slice(text, 0, 140)}"
        end
    end
  end

  defp message_text(%{content: content}) when is_list(content) do
    Enum.find_value(content, "", fn
      %{type: :text, text: text} when is_binary(text) -> text
      %{"type" => "text", "text" => text} when is_binary(text) -> text
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      text when is_binary(text) -> text
      _part -> nil
    end)
  end

  defp message_text(%{content: content}) when is_binary(content), do: content
  defp message_text(_message), do: ""

  defp active_bridge_count(bridges) do
    Enum.count(bridges, &(&1.status == "active"))
  end

  defp bridge_adapter(%{adapter: adapter}) when is_binary(adapter), do: adapter

  defp bridge_adapter(%{metadata: metadata, bridge_id: bridge_id}) do
    case map_value(metadata || %{}, :adapter) || map_value(metadata || %{}, :lab_adapter) do
      nil -> "bridge:#{bridge_id}"
      adapter -> to_string(adapter)
    end
  end

  defp bridge_adapter(_bridge), do: "unknown"

  defp participant_source(participant) do
    participant.metadata
    |> map_value(:source)
    |> case do
      nil -> external_source(participant.external_ids)
      source -> source
    end
  end

  defp external_source(external_ids) when is_map(external_ids) and map_size(external_ids) > 0 do
    external_ids
    |> Map.keys()
    |> List.first()
    |> to_string()
  end

  defp external_source(_external_ids), do: "local"

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp stringify_keys(_map), do: %{}

  defp map_value(map, key) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp map_value(_map, _key), do: nil

  defp blank_default("", default), do: default
  defp blank_default(value, _default), do: value

  defp truthy?(value) when value in [true, "true", "1", 1, "on"], do: true
  defp truthy?(_value), do: false
end

defmodule JidoChatUI.Agents.AutoStarter do
  @moduledoc false

  use GenServer
  require Logger

  alias JidoChatUI.Agents

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    send(self(), :start_agents)
    {:ok, opts}
  end

  @impl true
  def handle_info(:start_agents, state) do
    case Agents.ensure_started("room_assistant") do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("Room Assistant did not start automatically: #{inspect(reason)}")
    end

    {:noreply, state}
  end
end
