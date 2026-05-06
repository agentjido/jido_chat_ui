defmodule JidoChatUI.Adapters do
  @moduledoc """
  Catalog of adapter packages surfaced by the developer console.
  """

  @bundled [
    %{
      id: "github",
      name: "GitHub",
      module: Jido.Chat.GitHub.Adapter,
      surface: "issues, comments, reactions, webhooks",
      status: :bundled,
      config_fields: [
        %{key: "owner_repo", label: "Owner/repo", placeholder: "agentjido/jido_chat_ui"},
        %{key: "issue_number", label: "Issue number", placeholder: "1"},
        %{key: "token_env", label: "Token env", placeholder: "GITHUB_TOKEN"},
        %{
          key: "webhook_secret_env",
          label: "Webhook secret env",
          placeholder: "GITHUB_WEBHOOK_SECRET"
        }
      ]
    },
    %{
      id: "slack",
      name: "Slack",
      module: Jido.Chat.Slack.Adapter,
      surface: "channels, DMs, threads, reactions",
      status: :bundled,
      config_fields: [
        %{key: "channel_id", label: "Channel ID", placeholder: "C0123456789"},
        %{key: "user_id", label: "DM user ID", placeholder: "U0123456789"},
        %{key: "bot_token_env", label: "Bot token env", placeholder: "SLACK_BOT_TOKEN"},
        %{
          key: "signing_secret_env",
          label: "Signing secret env",
          placeholder: "SLACK_SIGNING_SECRET"
        },
        %{key: "app_token_env", label: "Socket mode token env", placeholder: "SLACK_APP_TOKEN"}
      ]
    },
    %{
      id: "telegram",
      name: "Telegram",
      module: Jido.Chat.Telegram.Adapter,
      surface: "bot chats, polling, webhooks",
      status: :bundled,
      config_fields: [
        %{key: "chat_id", label: "Chat ID", placeholder: "-1001234567890"},
        %{key: "thread_id", label: "Thread ID", placeholder: "123"},
        %{key: "bot_token_env", label: "Bot token env", placeholder: "TELEGRAM_BOT_TOKEN"}
      ]
    },
    %{
      id: "discord",
      name: "Discord",
      module: Jido.Chat.Discord.Adapter,
      surface: "messages, interactions, gateway/webhooks",
      status: :bundled,
      config_fields: [
        %{key: "channel_id", label: "Channel ID", placeholder: "123456789012345678"},
        %{key: "user_id", label: "DM user ID", placeholder: "123456789012345678"},
        %{key: "bot_token_env", label: "Bot token env", placeholder: "DISCORD_BOT_TOKEN"},
        %{
          key: "bot_user_id_env",
          label: "Bot user ID env",
          placeholder: "DISCORD_BOT_USER_ID"
        },
        %{key: "public_key_env", label: "Public key env", placeholder: "DISCORD_PUBLIC_KEY"}
      ]
    },
    %{
      id: "mattermost",
      name: "Mattermost",
      module: Jido.Chat.Mattermost.Adapter,
      surface: "team channels, threads, websocket/REST",
      status: :bundled,
      config_fields: [
        %{key: "base_url_env", label: "Base URL env", placeholder: "MATTERMOST_URL"},
        %{key: "token_env", label: "Token env", placeholder: "MATTERMOST_TOKEN"},
        %{key: "team_id", label: "Team ID", placeholder: ""},
        %{key: "channel_id", label: "Channel ID", placeholder: ""}
      ]
    },
    %{
      id: "x",
      name: "X / Twitter",
      module: Jido.Chat.X.Adapter,
      surface: "DMs and social messages when user-context credentials are available",
      status: :bundled,
      config_fields: [
        %{key: "recipient_id", label: "Recipient user ID", placeholder: ""},
        %{key: "conversation_id", label: "Conversation ID", placeholder: ""},
        %{key: "consumer_key_env", label: "Consumer key env", placeholder: "X_CONSUMER_KEY"},
        %{
          key: "consumer_secret_env",
          label: "Consumer secret env",
          placeholder: "X_CONSUMER_SECRET"
        },
        %{key: "access_token_env", label: "Access token env", placeholder: "X_ACCESS_TOKEN"},
        %{
          key: "access_token_secret_env",
          label: "Access token secret env",
          placeholder: "X_ACCESS_TOKEN_SECRET"
        }
      ]
    }
  ]

  @optional [
    %{
      id: "signal",
      name: "Signal",
      module: Jido.Chat.Signal.Adapter,
      surface: "personal secure DMs through signal-cli",
      status: :optional,
      reason: "Requires signal-cli and a registered local Signal account."
    }
  ]

  @runtime_requirements %{
    "github" => [["GITHUB_TOKEN"]],
    "slack" => [["SLACK_BOT_TOKEN"]],
    "telegram" => [["TELEGRAM_BOT_TOKEN"]],
    "discord" => [["DISCORD_BOT_TOKEN"]],
    "mattermost" => [
      ["MATTERMOST_URL", "MATTERMOST_TOKEN"],
      ["MATTERMOST_BASE_URL", "MATTERMOST_TOKEN"],
      ["MATTERMOST_URL", "MATTERMOST_BOT_TOKEN"],
      ["MATTERMOST_BASE_URL", "MATTERMOST_BOT_TOKEN"]
    ],
    "x" => [["X_CONSUMER_KEY", "X_CONSUMER_SECRET", "X_ACCESS_TOKEN", "X_ACCESS_TOKEN_SECRET"]],
    "signal" => [["SIGNAL_ACCOUNT", "SIGNAL_RPC_ENDPOINT"]]
  }

  def bundled, do: Enum.map(@bundled, &with_load_status/1)
  def optional, do: Enum.map(@optional, &with_load_status/1)
  def all, do: bundled() ++ optional()

  def get(id), do: Enum.find(all(), &(&1.id == id))
  def config_fields(nil), do: []
  def config_fields(""), do: []
  def config_fields(id), do: (get(id) || %{}) |> Map.get(:config_fields, [])

  def select_options do
    Enum.map(bundled(), &{&1.name, &1.id})
  end

  def health_statuses(env_fun \\ &System.get_env/1) do
    Enum.map(all(), &health_status(&1, env_fun))
  end

  def capability_status(adapter) do
    cond do
      is_nil(adapter) ->
        %{status: :unknown, detail: "Unknown adapter"}

      !adapter.loaded? ->
        %{status: :unavailable, detail: "Adapter package is not loaded"}

      true ->
        case Jido.Chat.Adapter.validate_capabilities(adapter.module) do
          :ok -> %{status: :valid, detail: "Capability matrix is valid"}
          {:error, reason} -> %{status: :invalid, detail: inspect(reason)}
        end
    end
  rescue
    exception ->
      %{status: :invalid, detail: Exception.message(exception)}
  catch
    kind, reason ->
      %{status: :invalid, detail: inspect({kind, reason})}
  end

  def health_status(adapter, env_fun \\ &System.get_env/1) do
    requirements = Map.get(@runtime_requirements, adapter.id, [])
    missing_env = missing_env(requirements, env_fun)

    status =
      cond do
        !adapter.loaded? -> :unavailable
        missing_env == [] -> :connected
        true -> :needs_config
      end

    adapter
    |> Map.take([:id, :name, :loaded?])
    |> Map.merge(%{
      short_name: short_name(adapter.id),
      status: status,
      missing_env: missing_env,
      title: health_title(adapter.name, status, missing_env)
    })
  end

  defp with_load_status(adapter) do
    Map.put(adapter, :loaded?, Code.ensure_loaded?(adapter.module))
  end

  defp missing_env([], _env_fun), do: []

  defp missing_env(requirement_groups, env_fun) do
    configured_group =
      Enum.find(requirement_groups, fn group ->
        Enum.all?(group, &present_env?(&1, env_fun))
      end)

    if configured_group do
      []
    else
      requirement_groups
      |> Enum.min_by(&length/1)
      |> Enum.reject(&present_env?(&1, env_fun))
    end
  end

  defp present_env?(key, env_fun) do
    key
    |> env_fun.()
    |> present?()
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp short_name("github"), do: "GH"
  defp short_name("telegram"), do: "TG"
  defp short_name("discord"), do: "DC"
  defp short_name("mattermost"), do: "MM"
  defp short_name("x"), do: "X"
  defp short_name("signal"), do: "SG"
  defp short_name(id), do: id |> String.slice(0, 2) |> String.upcase()

  defp health_title(name, :connected, _missing_env), do: "#{name}: connected"

  defp health_title(name, :needs_config, missing_env),
    do: "#{name}: missing #{Enum.join(missing_env, ", ")}"

  defp health_title(name, :unavailable, _missing_env), do: "#{name}: package unavailable"
end
