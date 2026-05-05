# Jido Chat UI Onboarding And Scope

## Purpose

`jido_chat_ui` is a Phoenix developer workbench for proving the `jido_chat_*`, `jido_messaging`, and `jidoka` ecosystem end to end.

It should feel like a small Slack-like app because rooms, messages, bridges, reactions, replies, media, and agents are easiest to understand in that shape. Its real purpose is narrower: help developers configure real chat adapters, test them safely, inspect what happened, and copy working implementation patterns into their own apps.

This is not intended to be a production chat product yet.

## What The Package Should Prove

The UI should let a developer prove these claims without writing custom glue code first:

1. A `jido_chat_*` adapter package is installed and its capability matrix is honest.
2. Required env vars are present and the provider account or app can authenticate.
3. A provider target can be bound to an internal Jido room.
4. Outbound text delivery works.
5. Inbound text ingestion works.
6. Replies, threads, reactions, and media are either supported or clearly reported as unsupported.
7. Raw provider payloads are preserved for debugging.
8. Normalized messages use the same internal shape across adapters.
9. `jido_messaging` can own durable state, delivery attempts, dedupe, dead letters, and signals.
10. Jidoka agents can join rooms as responders without a separate UI actor model.

## Primary Users

### Adapter Authors

Adapter authors use the UI to harden one adapter package at a time.

They need:

- capability validation
- env-var checklist
- live smoke tests
- raw payload inspection
- normalized message inspection
- clear unsupported-feature behavior
- repeatable cleanup notes for provider-side test messages

### App Developers

App developers use the UI as a reference implementation.

They need:

- a working Phoenix setup
- examples for rooms, bridges, listeners, polling, webhooks, and delivery
- a clear place to copy adapter configuration patterns from
- guidance on using `jido_messaging` as state
- guidance on adding Jidoka agents to a room

### Ecosystem Reviewers

Reviewers use the UI to understand the overall Jido Chat story.

They need:

- a short onboarding path
- adapter status at a glance
- demo rooms with visible messages
- clear docs embedded into the UI
- a public demo path that does not require private chat credentials

## Core Mental Model

### Room

A room is the internal shared Jido conversation.

Rooms are not owned by adapters. A room can have zero, one, or many bridges.

### Bridge

A bridge is a configured adapter instance plus non-secret provider configuration.

Bridge records should store provider IDs and env-var names. They should not store secret token values.

### Room Bridge Binding

A room bridge binding maps one bridge to one room and one external provider target.

Examples:

- Telegram bridge bound to a Telegram chat ID
- Slack bridge bound to a Slack channel ID
- Discord bridge bound to a Discord channel ID
- GitHub bridge bound to `owner/repo#issue`
- X bridge bound to a DM conversation ID

### Adapter Lab Room

An adapter lab room is a focused onboarding/test room with exactly one active bridge.

Examples:

- `Telegram Lab`
- `Slack Lab`
- `Discord Lab`
- `GitHub Lab`
- `X Lab`
- `Mattermost Lab`

Adapter lab rooms are the recommended onboarding shape because failures are easy to isolate.

### Shared Demo Room

A shared demo room has multiple active bridges.

Example:

- `All Bridges Demo`

This proves fan-in and fan-out after individual adapter lab rooms are working.

## Onboarding Strategy

Onboarding should progressively disclose complexity. The app should guide developers from local setup to real provider traffic in small steps.

### Step 1: Start Local

Goal: get the Phoenix app running and log in.

Developer actions:

1. Copy `.env.example` to `.env`.
2. Run setup and migrations.
3. Start Phoenix.
4. Log in with magic link.

UI should show:

- app purpose
- adapter status rail
- setup checklist
- links to configuration docs

### Step 2: Pick One Adapter

Goal: configure one provider, not all providers.

Developer actions:

1. Open adapter setup.
2. Pick Telegram, Slack, Discord, GitHub, X, or Mattermost.
3. Fill the required env vars.
4. Restart the server if env changed.
5. Run a lightweight auth check where supported.

UI should show:

- required env vars
- optional env vars
- package loaded status
- local config status
- provider-specific setup guide
- next action to create an adapter lab room

### Step 3: Create Adapter Lab Room

Goal: create a focused room for one adapter.

Developer actions:

1. Click `Create adapter lab room` from an adapter guide.
2. Review generated room name and description.
3. Save room.

UI should show:

- room purpose
- recommended next step to create a bridge
- link back to adapter guide

### Step 4: Create Bridge

Goal: create a configured adapter instance without storing secrets.

Developer actions:

1. Pick adapter.
2. Enter provider target IDs and env-var names.
3. Save bridge.

UI should show:

- inline setup guide for selected adapter
- field help for provider IDs
- reminder that secrets belong in `.env`
- next action to bind bridge to room

### Step 5: Bind Bridge To Room

Goal: map the internal room to the external provider target.

Developer actions:

1. Open room bridge settings.
2. Select bridge.
3. Enter external room, channel, issue, DM, or thread ID.
4. Set binding to `active`.

UI should show:

- active bindings
- bridge adapter
- external target
- setup guide link
- listener or polling status where available

### Step 6: Prove Local Room Behavior

Goal: verify room UI before provider traffic.

Developer actions:

1. Send a local UI message.
2. Confirm it appears in the Filament timeline.
3. Use source filters.

UI should show:

- local message in timeline
- source `ui`
- timestamp
- empty-state behavior

### Step 7: Prove Outbound Provider Delivery

Goal: send one known test message to the provider.

Developer actions:

1. Click `Send smoke message`.
2. Confirm destination and message content.
3. Verify the provider received it.

UI should show:

- action-time confirmation for external sending
- delivery attempt
- provider response
- provider message ID or timestamp
- cleanup note

### Step 8: Prove Inbound Provider Ingestion

Goal: send a provider-side message and see it in the room.

Developer actions:

1. Send a message in Telegram, Slack, Discord, GitHub, X, or Mattermost.
2. Watch listener, polling, or webhook status.
3. Confirm normalized message appears in the timeline.

UI should show:

- raw provider event
- normalized message
- route decision
- room timeline entry
- dedupe status

### Step 9: Widen Features

Goal: test richer chat behavior after text works.

Developer actions:

1. Test replies or threads.
2. Test reactions.
3. Test image or file delivery where supported.
4. Confirm unsupported features fail clearly.

UI should show:

- feature support matrix per adapter
- pass/fail state by feature
- raw provider errors
- normalized representation where supported

### Step 10: Add Jidoka Agent

Goal: show an agent participating in a room.

Developer actions:

1. Open room agents.
2. Attach Room Assistant.
3. Choose response policy.
4. Send a message that triggers the agent.

UI should show:

- attached agents
- policy
- visible agent response in the room
- separate run trace for debugging

## Recommended Route Shape

### Public Routes

- `/`
- `/users/register`
- `/users/log-in`
- `/guides`
- `/guides/getting-started`
- `/guides/configuration`
- `/guides/adapters`
- `/guides/adapters/:id`
- `/guides/rooms`
- `/guides/bridges`
- `/guides/agents`
- `/guides/jido-messaging`
- `/guides/building-a-new-adapter`
- `/guides/signal`

### Authenticated Setup Routes

- `/setup`
- `/setup/adapters`
- `/setup/adapters/:id`
- `/setup/rooms`

These should be workflow pages, not duplicate docs. They should render checklists, status, and actions using the docs as context.

### Room Routes

- `/rooms`
- `/rooms/new`
- `/rooms/:id`
- `/rooms/:id/edit`
- `/rooms/:id/bridges`
- `/rooms/:id/bridges/new`
- `/rooms/:id/events`
- `/rooms/:id/agents`
- `/rooms/:id/settings`

### Bridge Routes

- `/bridges`
- `/bridges/new`
- `/bridges/:id`
- `/bridges/:id/edit`
- `/bridges/:id/events`
- `/bridges/:id/outbound`

### Ops Routes

- `/ops`
- `/ops/signals`
- `/ops/deliveries`
- `/ops/dead-letters`
- `/ops/listeners`

### Webhook Routes

- `/webhooks/:bridge_id`

## Scope For Beta

Beta scope should stay focused on proving the ecosystem.

### Must Have

- Phoenix auth and local setup
- `.env.example`
- adapter status rail
- embedded Markdown docs
- adapter setup guide pages
- room CRUD
- bridge CRUD
- room bridge binding
- Filament room timeline
- local room composer
- one adapter lab room flow
- outbound smoke test flow for at least one adapter
- inbound observation path for at least one adapter
- raw event and normalized event inspection

### Should Have

- adapter lab room creation from adapter guide
- room-specific bridge setup wizard
- room-specific agent attachment page
- lightweight provider auth checks
- listener or polling state per bridge
- setup checklist dashboard
- GitHub public demo path
- Telegram, Slack, and Discord private chat smoke paths

### Could Have

- replay failed deliveries
- webhook simulator
- seeded demo rooms
- demo reset command
- import env keys from sibling adapter repos
- media preview in timeline
- reaction and reply visual treatments
- adapter capability comparison page

### Not In Scope Yet

- production-grade chat app
- multi-tenant admin model
- billing
- Matrix, Twilio, Intercom, Zendesk, or Teams
- storing raw provider secrets in the database
- full provider account management
- mobile-first polished chat client
- replacing provider dashboards

## Adapter Coverage Intent

### Included By Default

- GitHub
- Slack
- Telegram
- Discord
- Mattermost
- X / Twitter

### Optional

- Signal

Signal remains optional because it requires `signal-cli`, a registered local account, and more explicit local safety decisions.

### Roadmap Candidates

- WhatsApp
- Linear
- Google Chat
- Jira

These should be added only after the current bridge, room, docs, and runtime patterns are stable enough to copy.

## Jido Messaging Position

`jido_messaging` should be the recommended state and runtime layer.

Phoenix should own:

- auth
- pages
- forms
- guide rendering
- developer workflow

`jido_messaging` should own:

- normalized message persistence
- room bindings
- inbound routing
- outbound delivery attempts
- dedupe
- dead letters
- signals

The UI should make `jido_messaging` visible, not hide it. A developer should be able to inspect how an adapter event became a normalized room message.

## Jidoka Agent Position

The UI should not introduce a separate `Actors` context at this stage.

Humans authenticate through Phoenix. External participants arrive through adapter messages. Agents are Jidoka responders attached to rooms.

The first agent story should be:

1. Attach Room Assistant to a room.
2. Pick response policy.
3. Send a room message.
4. See the agent response in the timeline.
5. Open a run trace for debugging.

## UX Principles

- Do one provider at a time.
- Make secrets handling explicit.
- Prefer checklists over long prose inside workflow pages.
- Keep Markdown docs canonical.
- Render docs inside the UI with live status around them.
- Never require live provider traffic for basic local tests.
- Confirm before sending real external messages.
- Preserve raw provider payloads for debugging.
- Show unsupported features clearly.
- Keep adapter lab rooms separate from shared demo rooms.

## Gap Analysis Template

Use this document as the target state for gap analysis.

For each section, classify current state as:

- `Done`
- `Partial`
- `Missing`
- `Blocked`
- `Deferred`

Suggested gap table:

| Area | Target | Current | Gap | Priority | Next Step |
| --- | --- | --- | --- | --- | --- |
| Setup | `/setup` checklist exists |  |  |  |  |
| Guides | Markdown renders in UI |  |  |  |  |
| Adapter status | status rail and adapter pages |  |  |  |  |
| Rooms | local room composer and timeline |  |  |  |  |
| Adapter lab rooms | create from adapter guide |  |  |  |  |
| Bridges | configure non-secret provider IDs |  |  |  |  |
| Room bindings | bind bridge to provider target |  |  |  |  |
| Outbound | confirmed smoke send |  |  |  |  |
| Inbound | event reaches timeline |  |  |  |  |
| Events | raw and normalized inspection |  |  |  |  |
| Agents | attach Jidoka agent to room |  |  |  |  |
| Ops | deliveries, dead letters, listeners |  |  |  |  |

## Review Questions

Before implementing the next phase, decide:

1. Should `/setup` become the primary authenticated landing page instead of `/rooms`?
2. Should adapter guides create adapter lab rooms directly?
3. Should bridge creation be global, room-scoped, or both?
4. Which adapter should be the first complete end-to-end beta path?
5. Should GitHub remain the public demo path while Telegram, Slack, and Discord are private smoke paths?
6. How much of `jido_messaging` should be visible in the first beta UI?
7. What is the minimum Jidoka agent flow needed to prove the concept?

