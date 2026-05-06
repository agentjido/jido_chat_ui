# Jido Chat UI

Phoenix developer console for testing the `jido_chat_*`, `jido_messaging`, and `jidoka` ecosystem.

This repo is a local adapter workbench for development:

- pick one adapter
- check package, env, and capability readiness
- create or reuse a lab room, bridge, and binding
- send and receive messages through `jido_messaging`
- inspect raw payloads, normalized messages, persisted records, and delivery state
- attach Jidoka agents as room responders

## Status

Early local workbench. The app boots as a Phoenix/Postgres project and includes adapter labs, room and bridge management, guide pages, ops pages, a Filament-backed room timeline, `jido_messaging` Postgres persistence, and a basic Room Assistant.

Auth is not part of the product flow. The app uses one internal workspace identity for existing ownership fields and keeps provider secrets in `.env`.

## Setup

```sh
mix setup
cp .env.example .env
mix ecto.migrate
mix phx.server
```

Then open [localhost:4000/setup](http://localhost:4000/setup).

Copy values from `.env.example` into `.env` as you enable real adapters. The UI stores non-secret target IDs and env var names only.

## Included Adapters

The default dependency set includes every current showcase adapter except Signal:

- `jido_chat_github`
- `jido_chat_slack`
- `jido_chat_telegram`
- `jido_chat_discord`
- `jido_chat_mattermost`
- `jido_chat_x`

Signal is excluded by default because it requires `signal-cli`, a registered local Signal account, and local account safety decisions. To opt in:

```elixir
# mix.exs
{:jido_chat_signal, github: "agentjido/jido_chat_signal", branch: "main"}
```

Then install and register `signal-cli`, set `SIGNAL_ACCOUNT`, and create a Signal bridge from the UI.

## Jidoka Agents

The first included room agent is `JidoChatUI.Agents.RoomAssistant`.

The intended flow is:

1. A user or bridge posts a message into a room.
2. `jido_messaging` accepts and persists the event.
3. A room agent policy decides whether a Jidoka agent should respond.
4. The agent receives server-built context from the room, user, bridge, and message metadata.
5. The response is posted back through `jido_messaging`.

## Main Routes

- `/setup` - adapter readiness dashboard
- `/labs` - adapter lab selector
- `/labs/:adapter` - guided proof loop for one adapter
- `/rooms` - internal shared rooms
- `/rooms/new` - guided room creation
- `/rooms/:id` - Filament-backed room timeline and room state
- `/rooms/:id/bridges` - bind external adapter rooms to a room
- `/bridges` - configured adapter bridges
- `/bridges/new` - adapter picker and bridge creation
- `/agents` - available Jidoka agents
- `/ops` - runtime visibility
- `/guides` - interactive setup docs backed by repo Markdown
- `/guides/adapters` - adapter status and provider-specific setup guides
- `/guides/signal` - optional Signal setup
- `/webhooks/:bridge_id` - planned generic webhook endpoint

## Guide Docs

Repo Markdown in `docs/` is the source of truth. The Phoenix guide pages render those files in-app and add live adapter status, missing env vars, and next-step links around them.

Start with:

- `/guides/getting-started`
- `/guides/configuration`
- `/guides/adapters`

## Next Milestones

1. Add safe provider auth checks where adapters support them.
2. Add explicit outbound smoke-test confirmation per lab.
3. Add richer route-decision and delivery-result records.
4. Add generic webhook route through `Jido.Messaging.WebhookPlug`.
5. Expand ops around listener health, recent signals, failures, and dead letters.
