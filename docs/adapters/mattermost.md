# Mattermost Adapter

Mattermost is a useful open-source team-chat target. It is especially useful when you want a self-hosted provider for adapter testing.

## Supports

- team channels
- posts
- threads
- REST delivery
- websocket ingress where configured

## Required Env

```sh
MATTERMOST_URL=
MATTERMOST_BASE_URL=
MATTERMOST_TOKEN=
MATTERMOST_BOT_TOKEN=
MATTERMOST_TEAM_ID=
MATTERMOST_CHANNEL_ID=
```

The current adapters accept either `MATTERMOST_URL` or `MATTERMOST_BASE_URL` as the base URL convention. Prefer `MATTERMOST_URL` until package docs settle.

## Bridge Config

```elixir
%{
  "base_url_env" => "MATTERMOST_URL",
  "token_env" => "MATTERMOST_TOKEN",
  "team_id" => "team-id",
  "channel_id" => "channel-id"
}
```

## Smoke Test

1. Create a bot or personal access token for a test user.
2. Put the bot in a test channel.
3. Create a Mattermost bridge.
4. Bind it to a room.
5. Send a text post.
6. Reply in Mattermost and verify the inbound listener or polling path.

