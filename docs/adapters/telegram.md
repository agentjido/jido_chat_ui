# Telegram Adapter

Telegram is usually the easiest live chat adapter to test because bot setup is fast and polling is straightforward.

## Supports

- bot messages
- groups, supergroups, channels, and DMs where the bot has access
- polling
- webhooks
- forum topic thread IDs where configured
- photos and documents where the adapter supports media delivery

## Required Env

```sh
TELEGRAM_BOT_TOKEN=
TELEGRAM_TEST_CHAT_ID=
TELEGRAM_TEST_FORUM_CHAT_ID=
TELEGRAM_TEST_THREAD_ID=
TELEGRAM_TEST_REACTION=
TELEGRAM_TEST_PHOTO_REF=https://httpbin.org/image/png
TELEGRAM_TEST_DOCUMENT_REF=https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf
```

Only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_TEST_CHAT_ID` are needed for the first text smoke test.

## Provider Setup

1. Create a bot with BotFather.
2. Add the bot to a test chat.
3. Send a message in that chat.
4. Use `getUpdates` or the adapter helper scripts to find the chat ID.

## Bridge Config

```elixir
%{
  "chat_id" => "-1001234567890",
  "thread_id" => "123",
  "bot_token_env" => "TELEGRAM_BOT_TOKEN"
}
```

## Smoke Test

1. Create a Telegram bridge.
2. Bind it to a room with the chat ID.
3. Send an outbound text message.
4. Send a message from Telegram and verify polling sees it.
5. Test a photo or document after text works.

