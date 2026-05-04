defmodule JidoChatUIWeb.RoomLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Rooms
        <:actions>
          <.button variant="primary" navigate={~p"/rooms/new"}>
            <.icon name="hero-plus" /> New Room
          </.button>
        </:actions>
      </.header>

      <.table
        id="rooms"
        rows={@streams.rooms}
        row_click={fn {_id, room} -> JS.navigate(~p"/rooms/#{room}") end}
      >
        <:col :let={{_id, room}} label="Name">{room.name}</:col>
        <:col :let={{_id, room}} label="Description">{room.description}</:col>
        <:col :let={{_id, room}} label="Status">{room.status}</:col>
        <:col :let={{_id, room}} label="Metadata">{inspect(room.metadata)}</:col>
        <:action :let={{_id, room}}>
          <div class="sr-only">
            <.link navigate={~p"/rooms/#{room}"}>Show</.link>
          </div>
          <.link navigate={~p"/rooms/#{room}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, room}}>
          <.link
            phx-click={JS.push("delete", value: %{id: room.id}) |> hide("##{id}")}
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
      Chat.subscribe_rooms(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Rooms")
     |> stream(:rooms, list_rooms(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    room = Chat.get_room!(socket.assigns.current_scope, id)
    {:ok, _} = Chat.delete_room(socket.assigns.current_scope, room)

    {:noreply, stream_delete(socket, :rooms, room)}
  end

  @impl true
  def handle_info({type, %JidoChatUI.Chat.Room{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :rooms, list_rooms(socket.assigns.current_scope), reset: true)}
  end

  defp list_rooms(current_scope) do
    Chat.list_rooms(current_scope)
  end
end
