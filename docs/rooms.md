# Rooms

Rooms are the internal shared timeline owned by the workbench. They are where local users, provider bridges, and Jidoka agents meet.

## What A Room Proves

A room proves that messages can be normalized into one shared conversation even when they come from different providers.

Use rooms to inspect:

- local UI messages
- inbound adapter messages
- outbound bridge delivery
- Jidoka agent responses
- raw provider metadata

## Create A Room

Open `/rooms/new` and create a focused test room.

Good room names:

- `Telegram smoke test`
- `Slack bridge beta`
- `GitHub issue comments`

Avoid mixing unrelated provider tests in one room until each bridge works on its own.

## Next Step

After creating a room, open the room bridge settings page and bind one configured bridge.

