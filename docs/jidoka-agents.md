# Jidoka Agents

Jidoka agents should participate in rooms as chat responders. The UI does not need a separate `Actors` context for this stage.

## Model

- Human users authenticate through Phoenix.
- External participants arrive through adapter messages.
- Agents are Jidoka responders attached to rooms.
- Agent run traces are visible separately from user-visible chat messages.

## First Agent

The first included agent is `JidoChatUI.Agents.RoomAssistant`.

It should help with developer workflows:

- summarize room state
- explain bridge configuration
- respond to test messages
- identify which adapter produced a message
- call out missing config or delivery failures

## Room Attachment

Attach agents at the room level. Later, add policy controls:

- respond only when mentioned
- respond to every message
- respond only to local UI messages
- respond only to adapter messages
- pause agent responses

## Debugging

Keep user-visible chat and agent run traces separate. The room timeline should show the final agent response. The agent run page should show prompt, context, tool calls, and errors.

