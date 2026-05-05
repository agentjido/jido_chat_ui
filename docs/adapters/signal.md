# Signal Adapter

Signal is optional in `jido_chat_ui`. It is excluded from the default dependency set because it depends on `signal-cli` and a locally registered Signal account.

## Supports

- personal Signal DMs through `signal-cli`
- command-line sending
- RPC polling where `signal-cli` is running as a JSON-RPC service
- attachments where the adapter and local CLI support them

## Required Env

```sh
SIGNAL_TRANSPORT=cli
SIGNAL_RPC_ENDPOINT=http://127.0.0.1:8080/api/v1/rpc
SIGNAL_ACCOUNT=
SIGNAL_TEST_RECIPIENT=
SIGNAL_INGRESS_MODE=rpc_polling
SIGNAL_RECEIVE_TIMEOUT_S=1
SIGNAL_RECEIVE_MAX_MESSAGES=10
```

## Opt In

Add the package dependency:

```elixir
{:jido_chat_signal, github: "agentjido/jido_chat_signal", branch: "main"}
```

Install and register `signal-cli` before enabling live tests.

## Smoke Test

1. Verify `signal-cli` can send a message from your shell.
2. Start the RPC service if you want polling.
3. Create a Signal bridge.
4. Bind it to a room.
5. Send one message to a safe test recipient.
6. Test inbound polling from that same DM.

## Safety

Signal credentials are personal and local. Keep this adapter opt-in, and use a dedicated test number where possible.

