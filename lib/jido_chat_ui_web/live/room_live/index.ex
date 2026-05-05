defmodule JidoChatUIWeb.RoomLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Rooms
        <:subtitle>
          Use one focused lab room per adapter, then add a shared room after the bridge works.
        </:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/rooms/new"}>
            <.icon name="hero-plus" /> New Room
          </.button>
        </:actions>
      </.header>

      <div id="rooms" class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <article
          :for={{id, room} <- @streams.rooms}
          id={id}
          class="rounded-lg border border-base-300 bg-base-100 p-4"
        >
          <.link navigate={~p"/rooms/#{room}"} class="block hover:opacity-80">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <h2 class="truncate font-semibold"># {room.name}</h2>
                <p class="mt-1 line-clamp-2 text-sm opacity-70">{room.description}</p>
              </div>
              <span class="badge">{room.status}</span>
            </div>
          </.link>

          <div class="mt-4 flex items-center justify-between gap-3 border-t border-base-300 pt-3 text-sm">
            <span class="truncate opacity-60">{inspect(room.metadata || %{})}</span>
            <div class="flex shrink-0 gap-3">
              <.link navigate={~p"/rooms/#{room}/edit"}>Edit</.link>
              <.link
                phx-click={JS.push("delete", value: %{id: room.id}) |> hide("##{id}")}
                data-confirm="Are you sure?"
              >
                Delete
              </.link>
            </div>
          </div>
        </article>
      </div>
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
