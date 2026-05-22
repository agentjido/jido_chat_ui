defmodule JidoChatUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_chat_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {JidoChatUI.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.19"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:mdex, "~> 0.12"},
      {:filament, git: "https://github.com/jallum/filament.git", branch: "main"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dotenvy, "~> 1.1"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Jido runtime and adapter showcase dependencies.
      {:jido_chat, github: "agentjido/jido_chat", branch: "main", override: true},
      {:jido_messaging, github: "agentjido/jido_messaging", branch: "main"},
      {:jidoka, github: "agentjido/jidoka", branch: "main"},
      {:jido_ai, github: "agentjido/jido_ai", branch: "feat/structured-output", override: true},
      {:jido_chat_discord, github: "agentjido/jido_chat_discord", branch: "main"},
      {:jido_chat_github, github: "agentjido/jido_chat_github", branch: "main"},
      {:jido_chat_mattermost, github: "www-zaq-ai/jido_chat_mattermost", branch: "main"},
      {:jido_chat_slack, github: "agentjido/jido_chat_slack", branch: "main"},
      {:jido_chat_telegram, github: "agentjido/jido_chat_telegram", branch: "main"},
      {:jido_chat_x, github: "agentjido/jido_chat_x", branch: "main"},
      # Fresh 0.4.4 uses charlist elixirc_paths, which Elixir 1.20 rejects.
      {:fresh,
       github: "agentjido/fresh", ref: "8cb7bd05478d3ddbd4fd1939ac202b3a3393fc33", override: true},

      # Jido package quality baseline.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind jido_chat_ui", "esbuild jido_chat_ui"],
      "assets.deploy": [
        "tailwind jido_chat_ui --minify",
        "esbuild jido_chat_ui --minify",
        "phx.digest"
      ],
      q: ["quality"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --min-priority higher"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
