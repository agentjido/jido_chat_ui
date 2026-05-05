# Getting Started

`jido_chat_ui` is a Phoenix workbench for proving that Jido chat adapters can authenticate, bind to real provider conversations, normalize inbound messages, and send outbound messages from one shared room.

The fastest useful path is one room, one bridge, and one smoke message.

## 1. Boot The App

```sh
mix setup
cp .env.example .env
mix ecto.migrate
mix phx.server
```

Open the app, register or log in with a magic link, then use the adapter status rail in the navbar to see which adapters have enough local configuration to start testing.

## 2. Pick One Adapter

Start with the adapter whose provider app you already control. Telegram, Slack, and Discord are the easiest private chat systems to test. GitHub is the easiest public system to inspect from a browser.

Only set keys for the adapter you are testing. Leave everything else blank.

## 3. Create A Room

Create an internal room from `/rooms/new`. This is the shared Jido timeline where local users, bridges, and Jidoka agents meet.

Use a narrow room name like `Telegram smoke test` or `GitHub issue bridge` so delivery and cleanup are obvious.

## 4. Create A Bridge

Create a bridge from `/bridges/new`.

A bridge is the configured adapter instance. Store stable identifiers and env-var names on the bridge. Store real secrets in `.env`.

Examples:

- Telegram: `chat_id`, `bot_token_env`
- Slack: `channel_id`, `bot_token_env`
- Discord: `channel_id`, `bot_token_env`
- GitHub: `owner_repo`, `issue_number`, `token_env`

## 5. Bind The Bridge

Open `/rooms/:id/bridges` and bind the bridge to the provider target. This tells the workbench which external conversation maps to the Jido room.

Set the binding status to `active` when you are ready to test.

## 6. Send And Receive

Use the room timeline to send local messages. Use the provider client to send inbound messages. Adapter-specific guide pages explain what to watch and which provider IDs matter.

For a clean beta pass, prove each adapter can handle:

- outbound text
- inbound text
- provider metadata on normalized messages
- replies or threads where supported
- attachments where supported
- a clear unsupported result where the provider does not support a feature

## 7. Inspect Failures

Use Ops pages and bridge detail pages for runtime inspection. The workbench should expose enough information to answer:

- Which bridge handled this message?
- What raw provider payload arrived?
- What normalized Jido message was produced?
- What outbound delivery was attempted?
- Did the provider reject the request?

