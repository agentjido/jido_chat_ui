# Bridges

Bridges connect an internal Jido room to an external provider target.

A bridge record answers two questions:

1. Which adapter should be used?
2. Which provider target does this bridge talk to?

## Bridge Records

Create bridge records from `/bridges/new`.

The bridge should store stable identifiers and env-var names:

```elixir
%{
  "channel_id" => "C0123456789",
  "bot_token_env" => "SLACK_BOT_TOKEN"
}
```

Do not store secret token values on bridge records.

## Room Bindings

Open `/rooms/:id/bridges` to bind a configured bridge to a room.

The binding can carry the external room ID, thread ID, and status. Use `draft` while entering IDs. Switch to `active` when you are ready for live tests.

## Debugging

If a bridge does not work, check these in order:

1. Adapter status is green or intentionally yellow for unsupported optional features.
2. Required env vars are present.
3. The provider app or bot has access to the target channel, issue, DM, or group.
4. The bridge record stores the right provider IDs.
5. The room binding points to the intended bridge.

