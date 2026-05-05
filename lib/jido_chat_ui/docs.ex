defmodule JidoChatUI.Docs do
  @moduledoc """
  Markdown-backed guide catalog for the developer workbench.
  """

  @entries [
    %{
      id: "getting-started",
      title: "Getting Started",
      summary: "Create a room, configure one bridge, and prove one real message path.",
      path: "docs/getting-started.md",
      route: "/guides/getting-started",
      category: :workflow
    },
    %{
      id: "onboarding-scope",
      title: "Onboarding And Scope",
      summary: "Review the target developer journey before scoring the current build.",
      path: "docs/ONBOARDING_SCOPE.md",
      route: "/guides/onboarding-scope",
      category: :workflow
    },
    %{
      id: "configuration",
      title: "Configuration",
      summary: "Set env vars safely and understand adapter status checks.",
      path: "docs/configuration.md",
      route: "/guides/configuration",
      category: :workflow
    },
    %{
      id: "rooms",
      title: "Rooms",
      summary: "Use internal shared timelines as the meeting point for bridges and agents.",
      path: "docs/rooms.md",
      route: "/guides/rooms",
      category: :workflow
    },
    %{
      id: "bridges",
      title: "Bridges",
      summary: "Connect internal rooms to provider channels, issues, DMs, and threads.",
      path: "docs/bridges.md",
      route: "/guides/bridges",
      category: :workflow
    },
    %{
      id: "jidoka-agents",
      title: "Jidoka Agents",
      summary: "Attach Jidoka responders to rooms without adding a separate Actors context.",
      path: "docs/jidoka-agents.md",
      route: "/guides/agents",
      category: :workflow
    },
    %{
      id: "jido-messaging-state",
      title: "Jido Messaging State",
      summary: "Use jido_messaging as the recommended runtime state and delivery layer.",
      path: "docs/jido-messaging-state.md",
      route: "/guides/jido-messaging",
      category: :workflow
    },
    %{
      id: "building-a-new-adapter",
      title: "Building A New Adapter",
      summary: "Use the UI to prove adapter capability honesty and beta readiness.",
      path: "docs/building-a-new-adapter.md",
      route: "/guides/building-a-new-adapter",
      category: :workflow
    },
    %{
      id: "github",
      title: "GitHub Adapter",
      summary: "Public issue comment and webhook bridge setup.",
      path: "docs/adapters/github.md",
      route: "/guides/adapters/github",
      category: :adapter,
      adapter_id: "github"
    },
    %{
      id: "slack",
      title: "Slack Adapter",
      summary: "Slack channel, DM, thread, and Socket Mode setup.",
      path: "docs/adapters/slack.md",
      route: "/guides/adapters/slack",
      category: :adapter,
      adapter_id: "slack"
    },
    %{
      id: "telegram",
      title: "Telegram Adapter",
      summary: "Telegram bot chat, polling, webhook, and media setup.",
      path: "docs/adapters/telegram.md",
      route: "/guides/adapters/telegram",
      category: :adapter,
      adapter_id: "telegram"
    },
    %{
      id: "discord",
      title: "Discord Adapter",
      summary: "Discord bot, channel, gateway, and interaction setup.",
      path: "docs/adapters/discord.md",
      route: "/guides/adapters/discord",
      category: :adapter,
      adapter_id: "discord"
    },
    %{
      id: "mattermost",
      title: "Mattermost Adapter",
      summary: "Mattermost REST, websocket, channel, and thread setup.",
      path: "docs/adapters/mattermost.md",
      route: "/guides/adapters/mattermost",
      category: :adapter,
      adapter_id: "mattermost"
    },
    %{
      id: "x",
      title: "X / Twitter Adapter",
      summary: "X Direct Message setup with user-context credentials.",
      path: "docs/adapters/x.md",
      route: "/guides/adapters/x",
      category: :adapter,
      adapter_id: "x"
    },
    %{
      id: "signal",
      title: "Signal Adapter",
      summary: "Optional signal-cli setup for local Signal DMs.",
      path: "docs/adapters/signal.md",
      route: "/guides/signal",
      category: :adapter,
      adapter_id: "signal"
    }
  ]

  for %{path: path} <- @entries do
    @external_resource Path.expand("../../#{path}", __DIR__)
  end

  @docs Enum.map(@entries, fn entry ->
          path = Path.expand("../../#{entry.path}", __DIR__)
          Map.put(entry, :markdown, File.read!(path))
        end)

  def all, do: @docs

  def workflow_guides do
    Enum.filter(@docs, &(&1.category == :workflow))
  end

  def adapter_guides do
    Enum.filter(@docs, &(&1.category == :adapter))
  end

  def get(id) when is_binary(id) do
    Enum.find(@docs, &(&1.id == id))
  end

  def get!(id) when is_binary(id) do
    get(id) || raise ArgumentError, "unknown guide: #{id}"
  end

  def adapter_guide(adapter_id) when is_binary(adapter_id) do
    Enum.find(adapter_guides(), &(&1[:adapter_id] == adapter_id))
  end

  def to_html!(%{markdown: markdown}) do
    MDEx.to_html!(markdown,
      extension: [
        autolink: true,
        strikethrough: true,
        table: true,
        tasklist: true
      ],
      sanitize: MDEx.Document.default_sanitize_options()
    )
  end
end
