defmodule JidoChatUI.Agents.RoomAssistant do
  @moduledoc """
  Baseline Jidoka agent used by the room showcase.
  """

  use Jidoka.Agent

  agent :room_assistant do
    model(:fast)
    description("Helps developers test Jido chat rooms and bridges.")

    instructions("""
    You help developers test Jido chat adapters. Explain what happened in the room,
    keep responses concise, and call out bridge or delivery details when they are
    present in the runtime context.
    """)
  end
end
