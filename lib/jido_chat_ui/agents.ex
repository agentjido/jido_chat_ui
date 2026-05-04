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

  def list_agents, do: [agent_status(@room_assistant)]
  def get_agent("room_assistant"), do: agent_status(@room_assistant)
  def get_agent(_id), do: nil

  defp agent_status(agent) do
    Map.put(agent, :loaded?, Code.ensure_loaded?(agent.module))
  end
end
