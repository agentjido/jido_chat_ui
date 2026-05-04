defmodule JidoChatUIWeb.BridgeLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Bridges

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Bridges
        <:actions>
          <.button variant="primary" navigate={~p"/bridges/new"}>
            <.icon name="hero-plus" /> New Bridge
          </.button>
        </:actions>
      </.header>

      <.table
        id="bridges"
        rows={@streams.bridges}
        row_click={fn {_id, bridge} -> JS.navigate(~p"/bridges/#{bridge}") end}
      >
        <:col :let={{_id, bridge}} label="Name">{bridge.name}</:col>
        <:col :let={{_id, bridge}} label="Adapter">{bridge.adapter}</:col>
        <:col :let={{_id, bridge}} label="Status">{bridge.status}</:col>
        <:col :let={{_id, bridge}} label="Config">{inspect(bridge.config)}</:col>
        <:col :let={{_id, bridge}} label="Metadata">{inspect(bridge.metadata)}</:col>
        <:action :let={{_id, bridge}}>
          <div class="sr-only">
            <.link navigate={~p"/bridges/#{bridge}"}>Show</.link>
          </div>
          <.link navigate={~p"/bridges/#{bridge}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, bridge}}>
          <.link
            phx-click={JS.push("delete", value: %{id: bridge.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Bridges.subscribe_bridges(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Bridges")
     |> stream(:bridges, list_bridges(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    bridge = Bridges.get_bridge!(socket.assigns.current_scope, id)
    {:ok, _} = Bridges.delete_bridge(socket.assigns.current_scope, bridge)

    {:noreply, stream_delete(socket, :bridges, bridge)}
  end

  @impl true
  def handle_info({type, %JidoChatUI.Bridges.Bridge{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :bridges, list_bridges(socket.assigns.current_scope), reset: true)}
  end

  defp list_bridges(current_scope) do
    Bridges.list_bridges(current_scope)
  end
end
