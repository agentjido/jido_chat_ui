# Building A New Adapter

Use `jido_chat_ui` to prove a new adapter before publishing it.

## Beta Checklist

An adapter is ready for beta when the workbench can prove:

- capabilities validate against `Jido.Chat.Adapter`
- live tests are excluded by default
- required env vars are documented
- outbound text works
- inbound text works
- unsupported media/reply/reaction features are explicit
- bridge config has stable provider IDs and env-var names
- raw provider payloads are preserved for debugging
- normalized messages are shaped consistently with other adapters

## Capability Honesty

Only advertise features that the adapter can execute through the core path.

If `send_file` is advertised, the adapter must implement a file path that returns success or a provider-specific error. If webhooks are advertised as native, the adapter must implement the webhook callback expected by the core validator.

## Live Tests

Every adapter package should tag live tests with `@moduletag :live` and exclude live tests by default:

```elixir
ExUnit.configure(exclude: [live: true])
ExUnit.start()
```

Run live tests explicitly when env vars and safe test targets are configured.

## UI Proof

After package tests pass, add the adapter to this workbench and prove:

1. adapter status rail shows config state
2. bridge form exposes provider-specific fields
3. room binding accepts the external target
4. outbound smoke test sends to provider
5. inbound test appears in the room timeline
6. Ops shows raw and normalized event details

