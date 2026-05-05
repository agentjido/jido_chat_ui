# X / Twitter Adapter

X requires user-context credentials for Direct Message APIs. Treat live tests carefully because the credentials may be tied to a real account.

## Supports

- Direct Messages where the X app and account have access
- user-context OAuth 1.0a delivery
- webhook and CRC-style verification where configured

## Required Env

```sh
X_CONSUMER_KEY=
X_CONSUMER_SECRET=
X_ACCESS_TOKEN=
X_ACCESS_TOKEN_SECRET=
X_BEARER_TOKEN=
X_TEST_RECIPIENT_ID=
X_TEST_CONVERSATION_ID=
X_WEBHOOK_ID=
X_WEBHOOK_URL=
X_WEBHOOK_ENV_NAME=
SECRET_KEY=
```

Only the OAuth 1.0a consumer and access-token values are needed for the first direct-send test.

## Bridge Config

```elixir
%{
  "recipient_id" => "123456789",
  "conversation_id" => "123456789-987654321",
  "consumer_key_env" => "X_CONSUMER_KEY",
  "consumer_secret_env" => "X_CONSUMER_SECRET",
  "access_token_env" => "X_ACCESS_TOKEN",
  "access_token_secret_env" => "X_ACCESS_TOKEN_SECRET"
}
```

## Smoke Test

1. Confirm which X account owns the credentials.
2. Use a disposable recipient or private test conversation.
3. Create an X bridge.
4. Bind it to a room with the recipient or conversation ID.
5. Send one clearly labeled test DM.
6. Record the timestamp and content so cleanup is easy.

## Safety

Do not post public tweets from the workbench. Keep beta support scoped to Direct Messages until the adapter explicitly models public posting and cleanup.

