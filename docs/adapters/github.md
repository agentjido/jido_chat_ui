# GitHub Adapter

GitHub is the best public demo adapter because comments, reactions, and issue state are easy to inspect from a browser.

## Supports

- issue comments
- pull request comments through issue comment APIs
- reactions where the adapter exposes them
- webhook verification and parsing
- outbound comments to a configured issue

## Required Env

```sh
GITHUB_TOKEN=
GITHUB_WEBHOOK_SECRET=
GITHUB_TEST_ISSUE=agentjido/jido_chat_ui#1
```

Use a fine-grained personal access token or GitHub App installation token. For beta testing, grant the smallest repository scope that can create comments on the test issue.

## Bridge Config

Recommended bridge fields:

```elixir
%{
  "owner_repo" => "agentjido/jido_chat_ui",
  "issue_number" => "1",
  "token_env" => "GITHUB_TOKEN",
  "webhook_secret_env" => "GITHUB_WEBHOOK_SECRET"
}
```

## Smoke Test

1. Create a GitHub issue dedicated to adapter testing.
2. Set `GITHUB_TEST_ISSUE` to `owner/repo#number`.
3. Create a GitHub bridge.
4. Bind it to a room.
5. Send an outbound comment.
6. Open the issue in a browser and verify the comment.
7. Add a manual issue comment and verify the inbound webhook or replay path.

## Notes

Keep GitHub as the first fully documented public demo. It proves the adapter contract without requiring a private chat account.

