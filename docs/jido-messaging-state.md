# Jido Messaging State

`jido_messaging` should be the recommended state adapter for production chat behavior.

The Phoenix app should own user auth, pages, and UI state. `jido_messaging` should own message persistence, bridge routing, delivery attempts, dedupe, dead letters, and runtime signals.

## Recommended Boundary

- Phoenix: login, room pages, bridge forms, ops screens
- `jido_chat_*`: provider-specific adapter behavior
- `jido_messaging`: normalized runtime state and delivery lifecycle
- `jidoka`: agent authoring and execution
- Filament: high-change timeline and status UI components

## Message Flow

1. Provider event arrives from webhook, listener, or polling.
2. Adapter parses the provider payload.
3. `jido_messaging` normalizes and persists the message.
4. Room bindings route the message into one or more rooms.
5. Jidoka agent policy decides whether an agent should respond.
6. Outbound deliveries are attempted through configured bridges.
7. Delivery results and dead letters are visible in Ops.

## UI Goal

The UI should make this flow inspectable. A developer should be able to click from a room message to:

- normalized message fields
- raw provider payload
- bridge binding
- outbound delivery attempts
- dead-letter state if delivery failed

