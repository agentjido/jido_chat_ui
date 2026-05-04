defmodule JidoChatUI.Agents.RoomAssistant do
  @moduledoc """
  Baseline Jidoka agent used by the room showcase.
  """

  use Jidoka.Agent

  agent do
    id(:room_assistant)
    description("Helps developers test Jido chat rooms and bridges.")
  end

  defaults do
    model(:fast)

    instructions("""
    You help developers test Jido chat adapters. Explain what happened in the room,
    keep responses concise, and call out bridge or delivery details when they are
    present in the runtime context.
    """)
  end
end
