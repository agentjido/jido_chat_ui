defmodule JidoChatUI.Messaging.BridgeReconciler do
  @moduledoc """
  Starts persisted `jido_messaging` bridge listeners after the UI boots.

  Runtime bridge config writes already trigger reconciliation through
  `Jido.Messaging.ConfigStore`. This worker covers the cold-start case where
  bridge configs already exist in Postgres before Phoenix starts.
  """

  use GenServer

  require Logger

  @initial_delay_ms 500
  @interval_ms 30_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, @interval_ms)
    Process.send_after(self(), :reconcile, @initial_delay_ms)
    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:reconcile, state) do
    reconcile_bridges()

    Process.send_after(self(), :reconcile, state.interval_ms)
    {:noreply, state}
  end

  defp reconcile_bridges do
    Jido.Messaging.BridgeSupervisor.reconcile(JidoChatUI.Messaging)
  rescue
    exception ->
      Logger.warning("jido_messaging bridge reconcile failed: #{Exception.message(exception)}")
  catch
    kind, reason ->
      Logger.warning("jido_messaging bridge reconcile failed: #{inspect({kind, reason})}")
  end
end
