defmodule JidoChatUI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    configure_adapter_env()

    children =
      [
        JidoChatUIWeb.Telemetry,
        JidoChatUI.Repo,
        {DNSCluster, query: Application.get_env(:jido_chat_ui, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: JidoChatUI.PubSub},
        {Registry, keys: :unique, name: JidoChatUI.RoomTimeline.Registry},
        {DynamicSupervisor, strategy: :one_for_one, name: JidoChatUI.RoomTimeline.Supervisor},
        JidoChatUI.Messaging,
        JidoChatUI.Agents.AutoStarter,
        JidoChatUI.Agents.RoomResponder,
        # Start a worker by calling: JidoChatUI.Worker.start_link(arg)
        # {JidoChatUI.Worker, arg},
        # Start to serve requests, typically the last entry
        JidoChatUIWeb.Endpoint
      ]
      |> maybe_start_agent_responder()
      |> maybe_start_bridge_reconciler()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JidoChatUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JidoChatUIWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp configure_adapter_env do
    put_env_from_system(:jido_chat_telegram, :telegram_bot_token, "TELEGRAM_BOT_TOKEN")
  end

  defp put_env_from_system(app, key, env_key) do
    case System.get_env(env_key) do
      value when is_binary(value) and value != "" -> Application.put_env(app, key, value)
      _missing -> :ok
    end
  end

  defp maybe_start_bridge_reconciler(children) do
    if Application.get_env(:jido_chat_ui, :start_bridge_reconciler, true) do
      List.insert_at(children, -2, JidoChatUI.Messaging.BridgeReconciler)
    else
      children
    end
  end

  defp maybe_start_agent_responder(children) do
    if Application.get_env(:jido_chat_ui, :start_agent_responder, true) do
      children
    else
      List.delete(children, JidoChatUI.Agents.RoomResponder)
    end
  end
end
