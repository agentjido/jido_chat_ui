# Jido Chat UI

Phoenix developer console for testing the `jido_chat_*`, `jido_messaging`, and `jidoka` ecosystem.

This repo is a spike toward a simple Phoenix-based Slack clone for adapter development:

- create internal Jido rooms
- configure adapter bridges
- bind external rooms, channels, issues, DMs, or threads to shared rooms
- inspect runtime status, delivery, and signals
- attach Jidoka agents as room responders

## Status

Early spike. The app boots as a normal Phoenix/Postgres project and includes the first room, bridge, guide, agent, ops, and Filament-backed timeline screens. Runtime persistence still starts with `Jido.Messaging.Persistence.ETS`; a Postgres persistence adapter for `jido_messaging` is the next major milestone.

## Setup

```sh
mix setup
cp .env.example .env
mix ecto.migrate
mix phx.server
```

Then open [localhost:4000](http://localhost:4000).

Generated auth uses magic links. In dev, emails appear at `/dev/mailbox`.

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

1. Implement `JidoChatUI.Messaging.Persistence.Postgres`.
2. Hydrate the Filament timeline from `jido_messaging` persistence and delivery events.
3. Wire bridge configs into `JidoChatUI.Messaging.put_bridge_config/1`.
4. Add generic webhook route through `Jido.Messaging.WebhookPlug`.
5. Add outbound route selection for composer messages.
6. Add delivery attempts, dead letters, and signal stream UI.
