defmodule JidoChatUIWeb.OpsLive.Index do
  use JidoChatUIWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Operations
        <:subtitle>Runtime visibility for routing, delivery, dead letters, and signals.</:subtitle>
      </.header>

      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <.ops_card title="Signals" value={inspect(@signal_bus)} detail="Jido.Signal.Bus event stream" />
        <.ops_card title="Deliveries" value="0" detail="Delivery attempt UI is a Phase 5 target" />
        <.ops_card title="Dead letters" value="0" detail="Replay controls will sit here" />
        <.ops_card title="Runtime" value="ETS" detail="Postgres persistence adapter is planned next" />
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true

  defp ops_card(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-300 bg-base-100 p-4">
      <p class="text-sm opacity-70">{@title}</p>
      <p class="mt-2 text-xl font-semibold">{@value}</p>
      <p class="mt-2 text-xs opacity-60">{@detail}</p>
    </section>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Operations")
     |> assign(:signal_bus, Jido.Messaging.Supervisor.signal_bus_name(JidoChatUI.Messaging))}
  end
end
