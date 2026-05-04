defmodule JidoChatUIWeb.RoomLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat
  alias JidoChatUI.RoomTimeline

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
          {live_render(@socket, JidoChatUIWeb.RoomTimelineLive,
            id: "room-timeline-#{@room.id}",
            session: %{
              "room_id" => @room.id,
              "room_name" => @room.name,
              "current_user_email" => @current_scope.user.email
            }
          )}

          <form
            id="timeline-composer-form"
            class="border-t border-base-300 p-4"
            phx-submit="timeline_message"
          >
            <label class="sr-only" for={"timeline-composer-#{@composer_version}"}>Message</label>
            <textarea
              id={"timeline-composer-#{@composer_version}"}
              name="body"
              class="textarea min-h-24 w-full resize-y"
              placeholder="Send a local room message"
            ></textarea>
            <div class="mt-3 flex items-center justify-between gap-3">
              <p class="text-xs opacity-60">
                Local messages stay in the in-memory Filament timeline until persistence lands.
              </p>
              <.button variant="primary" phx-disable-with="Sending...">Send</.button>
            </div>
          </form>
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
     |> assign(:composer_version, 0)
     |> assign(:room, Chat.get_room!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_event("timeline_message", %{"body" => body}, socket) do
    body = String.trim(to_string(body))

    if body != "" do
      socket.assigns.room.id
      |> RoomTimeline.ensure_started(socket.assigns.room.name)
      |> RoomTimeline.post_message(%{
        author: socket.assigns.current_scope.user.email,
        body: body,
        source: "ui",
        status: "sent"
      })
    end

    {:noreply, update(socket, :composer_version, &(&1 + 1))}
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
