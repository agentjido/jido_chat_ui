# Jido Chat UI Implementation Plan

## Goal

Build a Phoenix/Postgres developer console that showcases `jido_chat_*`, `jido_messaging`, and `jidoka` together.

The UI should guide a developer through a real workflow:

1. Create a room.
2. Configure a bridge.
3. Bind the bridge to the room.
4. Add a Jidoka room assistant.
5. Send or receive messages through the runtime.
6. Inspect routing, delivery, failures, and signals.

## Boundaries

- Phoenix owns auth, pages, route structure, and developer workflow.
- `jido_messaging` owns runtime state, ingress, outbound delivery, dedupe, dead letters, and signals.
- `jido_chat_*` adapters own platform-specific send/parse/verify behavior.
- `jidoka` owns agent authoring and execution.
- Filament owns high-change LiveView components such as room timelines and bridge status panels.

Do not add a generic `Actors` context yet. Users authenticate through Phoenix. Chat participants come from `jido_messaging`. Agents are Jidoka responders attached to rooms.

## Route Map

Public:

- `/`
- `/users/register`
- `/users/log-in`
- `/guides`
- `/guides/getting-started`
- `/guides/rooms`
- `/guides/bridges`
- `/guides/agents`
- `/guides/signal`

Authenticated:

- `/rooms`
- `/rooms/new`
- `/rooms/:id`
- `/rooms/:id/edit`
- `/rooms/:id/bridges`
- `/bridges`
- `/bridges/new`
- `/bridges/:id`
- `/bridges/:id/edit`
- `/agents`
- `/agents/:id`
- `/ops`
- `/ops/signals`
- `/ops/deliveries`
- `/ops/dead-letters`

Planned:

- `/webhooks/:bridge_id`
- `/bridges/:bridge_id/events`
- `/bridges/:bridge_id/outbound`
- `/agents/:id/runs`

## Phases

### Phase 0: Shell

- Phoenix 1.8 app
- Postgres
- generated auth
- local Swoosh mailbox
- base navigation
- Jido/Jidoka/adapter dependencies

### Phase 1: Guided Setup

- room CRUD
- bridge CRUD
- room bridge binding
- guide pages
- adapter catalog
- room assistant catalog

### Phase 2: Runtime Integration

- start `JidoChatUI.Messaging`
- bridge records sync into `Jido.Messaging.BridgeConfig`
- webhook endpoint calls `Jido.Messaging.WebhookPlug`
- room bridge binding syncs into `jido_messaging` room bindings

### Phase 3: Filament Timeline

- observable room timeline server
- timeline component with projections
- Phoenix composer posting into the observable timeline
- live bridge status panels

### Phase 4: Jidoka Room Agents

- attach/detach room assistant
- room agent policy
- server-built runtime context
- agent response posted through `jido_messaging`
- debug/run trace panel separated from user-visible messages

### Phase 5: Ops

- outbound deliveries
- dead letters and replay
- signal stream
- bridge listener health
- adapter capability diagnostics

## First Real Demo

GitHub should be the first public demo because it does not require a private chat account:

1. Create room: `GitHub package beta`.
2. Create GitHub bridge.
3. Bind bridge to `agentjido/jido_chat_ui#<issue>`.
4. Post a UI message as an issue comment.
5. Receive webhook replay into the timeline.
6. Show delivery status and adapter metadata.
