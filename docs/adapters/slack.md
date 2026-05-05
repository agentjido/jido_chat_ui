# Slack Adapter

Slack is a primary team-chat target for Jido Chat. Use a test workspace and a dedicated test channel.

## Supports

- channel messages
- direct messages where bot scopes allow them
- threads
- reactions where configured
- webhook or Socket Mode ingress when the Slack app is configured correctly

## Required Env

```sh
SLACK_BOT_TOKEN=
SLACK_SIGNING_SECRET=
SLACK_APP_TOKEN=
SLACK_TEST_CHANNEL_ID=
SLACK_TEST_USER_ID=
SLACK_TEST_REACTION=wave
```

`SLACK_APP_TOKEN` is only needed for Socket Mode. If Socket Mode is not ready, the workbench can still use bot-token API checks and explicit polling-style smoke tests.

## Slack App Setup

Create a Slack app and install it into the workspace. Start with these bot scopes:

- `chat:write`
- `channels:read`
- `channels:history`
- `reactions:write`
- `im:read`
- `im:write`

Add more scopes only when a test proves they are needed.

## Bridge Config

```elixir
%{
  "channel_id" => "C0123456789",
  "bot_token_env" => "SLACK_BOT_TOKEN",
  "app_token_env" => "SLACK_APP_TOKEN",
  "signing_secret_env" => "SLACK_SIGNING_SECRET"
}
```

## Smoke Test

1. Add the bot to the test channel.
2. Create a Slack bridge.
3. Bind the bridge to the room with the channel ID.
4. Send an outbound message from the workbench.
5. Post a message in Slack and verify the inbound path.
6. Test a thread reply after text works.

