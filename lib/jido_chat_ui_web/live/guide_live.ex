defmodule JidoChatUIWeb.GuideLive do
  use JidoChatUIWeb, :live_view

  @guides %{
    index: %{
      title: "Guides",
      summary: "Use these short guides to wire a room, bridge, and Jidoka agent together.",
      steps: [
        {"Create a room", "/rooms/new", "Start with the internal timeline that Jido owns."},
        {"Configure a bridge", "/bridges/new", "Pick an adapter and capture non-secret config."},
        {"Bind the bridge", "/rooms", "Open a room and add an external room or issue binding."},
        {"Attach an agent", "/agents", "Use the Room Assistant as the first Jidoka responder."}
      ]
    },
    getting_started: %{
      title: "Getting Started",
      summary: "The shortest path is one room, one bridge, and one test message.",
      steps: [
        {"Create room", "/rooms/new",
         "Name the shared room and leave it in draft or active state."},
        {"Create bridge", "/bridges/new", "GitHub is the easiest public adapter to try first."},
        {"Bind bridge", "/rooms", "Add the external room ID, issue number, channel, or DM ID."},
        {"Inspect delivery", "/ops/deliveries", "Use the ops pages to verify routing outcomes."}
      ]
    },
    rooms: %{
      title: "Rooms",
      summary: "Rooms are the internal shared timeline. Bridges and agents attach to rooms.",
      steps: [
        {"Internal room", "/rooms/new", "Create a durable UI room record."},
        {"External bindings", "/rooms",
         "Bind platform rooms through the room bridge settings page."},
        {"Timeline", "/rooms", "Use room detail as the primary chat and inspection surface."}
      ]
    },
    bridges: %{
      title: "Bridges",
      summary:
        "Bridges are configured adapter instances. Keep secrets in env vars for the spike.",
      steps: [
        {"Pick adapter", "/bridges/new", "Choose from bundled adapters except Signal."},
        {"Store config", "/bridges/new",
         "Capture labels and metadata, not raw production secrets."},
        {"Bind to rooms", "/rooms", "A bridge becomes useful once attached to a room."}
      ]
    },
    agents: %{
      title: "Agents",
      summary: "Agents are Jidoka responders attached to rooms, not separate UI actors.",
      steps: [
        {"Room Assistant", "/agents/room_assistant", "Start with the built-in room assistant."},
        {"Runtime context", "/agents",
         "Agent context is built server-side from room and bridge metadata."},
        {"Debug separately", "/agents/room_assistant/runs",
         "Visible chat and run traces should stay separate."}
      ]
    },
    signal: %{
      title: "Signal",
      summary:
        "Signal is optional because it requires signal-cli and a registered local account.",
      steps: [
        {"Install signal-cli", "https://github.com/AsamK/signal-cli",
         "Register or link an account locally."},
        {"Add dependency", "https://github.com/agentjido/jido_chat_signal",
         "Add jido_chat_signal to mix.exs when you want to opt in."},
        {"Configure env", "/bridges/new", "Set sender account details outside committed config."}
      ]
    }
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@guide.title}
        <:subtitle>{@guide.summary}</:subtitle>
      </.header>

      <div class="grid gap-4 md:grid-cols-2">
        <.link
          :for={{label, path, detail} <- @guide.steps}
          navigate={internal_path(path)}
          href={external_path(path)}
          class="rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
        >
          <p class="font-medium">{label}</p>
          <p class="mt-1 text-sm opacity-70">{detail}</p>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    guide = Map.fetch!(@guides, socket.assigns.live_action || :index)

    {:ok,
     socket
     |> assign(:page_title, guide.title)
     |> assign(:guide, guide)}
  end

  defp internal_path("http" <> _), do: nil
  defp internal_path(path), do: path

  defp external_path("http" <> _ = path), do: path
  defp external_path(_), do: nil
end
