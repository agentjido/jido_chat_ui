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
      status: :bundled
    },
    %{
      id: "slack",
      name: "Slack",
      module: Jido.Chat.Slack.Adapter,
      surface: "channels, DMs, threads, reactions",
      status: :bundled
    },
    %{
      id: "telegram",
      name: "Telegram",
      module: Jido.Chat.Telegram.Adapter,
      surface: "bot chats, polling, webhooks",
      status: :bundled
    },
    %{
      id: "discord",
      name: "Discord",
      module: Jido.Chat.Discord.Adapter,
      surface: "messages, interactions, gateway/webhooks",
      status: :bundled
    },
    %{
      id: "mattermost",
      name: "Mattermost",
      module: Jido.Chat.Mattermost.Adapter,
      surface: "team channels, threads, websocket/REST",
      status: :bundled
    },
    %{
      id: "x",
      name: "X / Twitter",
      module: Jido.Chat.X.Adapter,
      surface: "DMs and social messages when user-context credentials are available",
      status: :bundled
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

  def bundled, do: Enum.map(@bundled, &with_load_status/1)
  def optional, do: Enum.map(@optional, &with_load_status/1)
  def all, do: bundled() ++ optional()

  def get(id), do: Enum.find(all(), &(&1.id == id))

  def select_options do
    Enum.map(bundled(), &{&1.name, &1.id})
  end

  defp with_load_status(adapter) do
    Map.put(adapter, :loaded?, Code.ensure_loaded?(adapter.module))
  end
end
