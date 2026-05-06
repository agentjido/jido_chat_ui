# Jido Chat UI Product Direction

## Positioning

`jido_chat_ui` should be an adapter workbench.

It can look like a small chat app, but its job is not to compete with Slack. Its
job is to help developers prove that a `jido_chat_*` adapter works with
`jido_messaging` and `jidoka`.

## Core Loop

Keep the product centered on one repeatable loop:

1. Pick one adapter.
2. Check configuration.
3. Bind one external target to one internal room.
4. Send one message out.
5. Receive one message in.
6. Inspect the raw payload, normalized message, persistence record, and delivery result.
7. Add the Room Assistant and prove an agent can participate.

Everything else should support this loop.

## Product Constraints

- This is a local developer workbench, not a hosted multi-user chat product.
- User-facing auth is out of scope; the app uses one internal workspace identity
  only to satisfy existing `user_id` fields.
- Provider secrets stay in `.env`. The UI may display env var names and
  non-secret target IDs, but it should not store tokens in Postgres.
- Signal remains optional documentation because it needs `signal-cli` and a
  registered local account.

## Minimum Potent App

### Dashboard

The first screen should answer:

- Which adapters are installed?
- Which adapters are configured?
- Which one should I test next?

### Adapter Lab

One page per adapter should guide the whole test:

- package loaded
- required env vars present
- capability matrix valid
- provider auth check, where available
- lab room exists
- bridge exists
- external target bound
- outbound smoke test
- inbound smoke test
- optional replies, reactions, media, and threads

This should replace most first-time room and bridge CRUD.

The default flow is:

1. Open `/setup`.
2. Pick an adapter from `/labs`.
3. Prepare `/labs/:adapter`.
4. Open the generated room.
5. Send and receive a message.
6. Inspect the selected message.
7. Enable the Room Assistant when the transport is proven.

### Room

The room is the proof surface:

- timeline
- composer
- participants
- active bridge
- Room Assistant controls
- selected message inspector

The room should make it obvious what came from the UI, what came from an adapter,
and what came from an agent.

### Inspector

The inspector is what makes the tool valuable.

For any message or delivery, show:

- raw provider payload
- normalized `jido_chat` shape
- persisted `jido_messaging` record
- route decision
- delivery result or error

### Ops

Keep ops narrow:

- listener or poller health
- recent signals
- delivery failures
- dead letters

Do not build a large observability product yet.

## What To Hide At First

Keep these available, but move them behind advanced links:

- generic room CRUD
- generic bridge CRUD
- manual room-bridge binding
- low-level routing policy editing
- raw signal stream browsing

Developers should not need to understand every internal record before sending
the first test message.

## Agent Model

Do not create a separate UI actor system.

Use `jido_messaging` participants:

- Phoenix users are human participants.
- External users are adapter participants.
- Jidoka agents are agent participants.

The first agent is `Room Assistant`.

Room-level controls are enough:

- deterministic or LLM mode
- local-only replies
- relay replies through active bridges
- auto-reply to adapter messages

## Product Test

The app is useful if a developer can answer these questions in under five
minutes for one adapter:

1. Is it installed?
2. Is it configured?
3. Can it authenticate?
4. Can it send?
5. Can it receive?
6. What did the provider send?
7. What did Jido normalize?
8. What did `jido_messaging` persist?
9. Why did anything fail?
10. Can an agent safely join the room?
