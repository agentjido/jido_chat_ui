# Configuration

Configuration lives in `.env`. The checked-in `.env.example` is the source for supported variables and safe defaults.

Never commit `.env`.

## Loading Config

The Phoenix app loads `.env` through `dotenvy` during local development. Restart the server after changing keys.

```sh
cp .env.example .env
mix phx.server
```

## Status Colors

The navbar adapter rail uses lightweight local checks:

- Green: adapter package is loaded and required env vars are present.
- Yellow: adapter package is loaded, but one or more required env vars are missing.
- Red: adapter package is not loaded in this app.

These checks do not always prove that the provider accepted the token. Use each adapter guide to run the deeper auth or smoke test.

## Secret Handling

Bridge records should store names and stable provider IDs, not raw secrets.

Good bridge config:

```elixir
%{
  "channel_id" => "C0123456789",
  "bot_token_env" => "SLACK_BOT_TOKEN"
}
```

Avoid bridge config like this:

```elixir
%{
  "bot_token" => "xoxb-..."
}
```

## Test Targets

Use disposable targets for live testing:

- a test Slack channel
- a private Telegram test group
- a Discord test channel
- a GitHub issue created for adapter smoke tests
- a separate X test conversation

Keep a note of every provider message the workbench sends so cleanup is straightforward.

