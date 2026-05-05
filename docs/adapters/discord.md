# Discord Adapter

Discord is useful for testing gateway-style chat, channel IDs, and bot identity.

## Supports

- channel messages
- DMs where the bot and application configuration allow them
- gateway ingress
- interactions and public-key verification where configured
- reactions where supported by the adapter

## Required Env

```sh
DISCORD_BOT_TOKEN=
DISCORD_PUBLIC_KEY=
DISCORD_TEST_CHANNEL_ID=
DISCORD_TEST_USER_ID=
DISCORD_TEST_REACTION=
```

Only `DISCORD_BOT_TOKEN` and `DISCORD_TEST_CHANNEL_ID` are needed for a basic channel text smoke test.

## Provider Setup

1. Create a Discord application.
2. Add a bot to the application.
3. Invite the bot into a test server.
4. Grant channel read and send permissions in the test channel.
5. Enable intents only when the adapter test requires them.

## Bridge Config

```elixir
%{
  "channel_id" => "123456789012345678",
  "bot_token_env" => "DISCORD_BOT_TOKEN",
  "public_key_env" => "DISCORD_PUBLIC_KEY"
}
```

## Smoke Test

1. Create a Discord bridge.
2. Bind it to a room with the channel ID.
3. Send an outbound text message.
4. Post in Discord and verify the inbound path.
5. Add reaction and reply tests only after text is clean.

