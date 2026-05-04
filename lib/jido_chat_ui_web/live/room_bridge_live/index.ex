defmodule JidoChatUIWeb.RoomBridgeLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Bridges
  alias JidoChatUI.Chat
  alias JidoChatUI.Chat.RoomBridge

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Bridges for {@room.name}
        <:subtitle>
          Bind this internal room to external chat rooms, issues, channels, or DMs.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/rooms/#{@room}"}>
            <.icon name="hero-arrow-left" /> Back to room
          </.button>
          <.button navigate={~p"/bridges/new"}>
            <.icon name="hero-plus" /> New bridge
          </.button>
        </:actions>
      </.header>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="space-y-3">
          <h2 class="text-base font-semibold">Connected bridges</h2>
          <div
            :if={@room_bridges == []}
            class="rounded-lg border border-dashed p-6 text-sm opacity-70"
          >
            No bridges are bound to this room yet.
          </div>
          <div
            :for={binding <- @room_bridges}
            class="rounded-lg border border-base-300 bg-base-100 p-4"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="font-medium">{bridge_name(@bridges, binding.bridge_id)}</p>
                <p class="text-sm opacity-70">{binding.external_room_id}</p>
              </div>
              <span class="badge badge-outline">{binding.status}</span>
            </div>
            <p :if={binding.external_thread_id} class="mt-2 text-xs opacity-60">
              Thread: {binding.external_thread_id}
            </p>
          </div>
        </section>

        <section class="rounded-lg border border-base-300 bg-base-100 p-4">
          <h2 class="text-base font-semibold">Add a bridge</h2>
          <p class="mt-1 text-sm opacity-70">
            Pick a configured adapter bridge and tell Jido which external room it maps to.
          </p>
          <.form
            for={@form}
            id="room-bridge-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-4"
          >
            <.input field={@form[:room_id]} type="hidden" />
            <.input
              field={@form[:bridge_id]}
              type="select"
              label="Bridge"
              prompt="Choose a bridge"
              options={@bridge_options}
            />
            <.input field={@form[:external_room_id]} type="text" label="External room ID" />
            <.input field={@form[:external_thread_id]} type="text" label="External thread ID" />
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={[{"Draft", "draft"}, {"Active", "active"}, {"Paused", "paused"}]}
            />
            <.button variant="primary" phx-disable-with="Binding...">Bind bridge</.button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    scope = socket.assigns.current_scope
    room = Chat.get_room!(scope, room_id)

    room_bridge = %RoomBridge{
      user_id: scope.user.id,
      room_id: room.id,
      status: "draft",
      metadata: %{}
    }

    {:ok,
     socket
     |> assign(:page_title, "Room Bridges")
     |> assign(:room, room)
     |> assign(:bridges, Bridges.list_bridges(scope))
     |> assign(:bridge_options, Bridges.bridge_options(scope))
     |> assign(:room_bridges, Chat.list_room_bridges_for_room(scope, room.id))
     |> assign(:room_bridge, room_bridge)
     |> assign(:form, to_form(Chat.change_room_bridge(scope, room_bridge)))}
  end

  @impl true
  def handle_event("validate", %{"room_bridge" => params}, socket) do
    changeset =
      Chat.change_room_bridge(socket.assigns.current_scope, socket.assigns.room_bridge, params)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"room_bridge" => params}, socket) do
    params = Map.put(params, "room_id", socket.assigns.room.id)

    case Chat.create_room_bridge(socket.assigns.current_scope, params) do
      {:ok, _binding} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bridge bound to room")
         |> push_navigate(to: ~p"/rooms/#{socket.assigns.room}/bridges")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp bridge_name(bridges, bridge_id) do
    bridges
    |> Enum.find(&(&1.id == bridge_id))
    |> case do
      nil -> "Bridge #{bridge_id}"
      bridge -> bridge.name
    end
  end
end
