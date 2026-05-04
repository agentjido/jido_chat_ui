defmodule JidoChatUIWeb.BridgeLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Bridges

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@bridge.name}
        <:subtitle>{(@adapter && @adapter.surface) || "Adapter bridge configuration."}</:subtitle>
        <:actions>
          <.button navigate={~p"/bridges"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/bridges/#{@bridge}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit bridge
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@bridge.name}</:item>
        <:item title="Adapter">{@bridge.adapter}</:item>
        <:item title="Status">{@bridge.status}</:item>
        <:item title="Loaded">{inspect(@adapter && @adapter.loaded?)}</:item>
        <:item title="Config">{inspect(@bridge.config || %{})}</:item>
        <:item title="Metadata">{inspect(@bridge.metadata || %{})}</:item>
      </.list>

      <section class="rounded-lg border border-base-300 bg-base-100 p-4">
        <h2 class="font-semibold">Next steps</h2>
        <div class="mt-3 flex flex-wrap gap-2">
          <.link navigate={~p"/rooms"} class="btn btn-sm">Bind to room</.link>
          <.link navigate={~p"/guides/bridges"} class="btn btn-sm btn-ghost">Bridge guide</.link>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Bridges.subscribe_bridges(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Bridge")
     |> assign_bridge(Bridges.get_bridge!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %JidoChatUI.Bridges.Bridge{id: id} = bridge},
        %{assigns: %{bridge: %{id: id}}} = socket
      ) do
    {:noreply, assign_bridge(socket, bridge)}
  end

  def handle_info(
        {:deleted, %JidoChatUI.Bridges.Bridge{id: id}},
        %{assigns: %{bridge: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current bridge was deleted.")
     |> push_navigate(to: ~p"/bridges")}
  end

  def handle_info({type, %JidoChatUI.Bridges.Bridge{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp assign_bridge(socket, bridge) do
    socket
    |> assign(:bridge, bridge)
    |> assign(:adapter, JidoChatUI.Adapters.get(bridge.adapter))
  end
end
