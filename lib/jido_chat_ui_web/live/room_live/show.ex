defmodule JidoChatUIWeb.RoomLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@room.name}
        <:subtitle>{@room.description || "Internal shared room for adapter testing."}</:subtitle>
        <:actions>
          <.button navigate={~p"/rooms"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/rooms/#{@room}/bridges"}>
            <.icon name="hero-link" /> Bridges
          </.button>
          <.button variant="primary" navigate={~p"/rooms/#{@room}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit room
          </.button>
        </:actions>
      </.header>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="rounded-lg border border-base-300 bg-base-100">
          <div class="border-b border-base-300 px-4 py-3">
            <h2 class="font-semibold">Timeline</h2>
            <p class="text-sm opacity-70">Filament-backed live timeline lands here next.</p>
          </div>
          <div class="space-y-3 p-4">
            <div class="rounded-lg bg-base-200 p-3">
              <p class="text-sm font-medium">System</p>
              <p class="mt-1 text-sm opacity-80">
                Room is ready. Add a bridge, then send a message from the adapter or the composer.
              </p>
            </div>
          </div>
        </section>

        <aside class="space-y-4">
          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Room settings</h2>
            <.list>
              <:item title="Status">{@room.status}</:item>
              <:item title="Metadata">{inspect(@room.metadata || %{})}</:item>
            </.list>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Agent</h2>
            <p class="mt-2 text-sm opacity-70">
              Attach the Room Assistant from the agents page to test Jidoka responses.
            </p>
            <.link navigate={~p"/agents/room_assistant"} class="btn btn-sm mt-3">Open agent</.link>
          </section>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Room")
     |> assign(:room, Chat.get_room!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %JidoChatUI.Chat.Room{id: id} = room},
        %{assigns: %{room: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :room, room)}
  end

  def handle_info(
        {:deleted, %JidoChatUI.Chat.Room{id: id}},
        %{assigns: %{room: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current room was deleted.")
     |> push_navigate(to: ~p"/rooms")}
  end

  def handle_info({type, %JidoChatUI.Chat.Room{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
