defmodule JidoChatUIWeb.AgentLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@agent.name}
        <:subtitle>{@agent.description}</:subtitle>
        <:actions>
          <.button navigate={~p"/agents"}>
            <.icon name="hero-arrow-left" /> Back
          </.button>
        </:actions>
      </.header>

      <div class="grid gap-4 lg:grid-cols-2">
        <section class="rounded-lg border border-base-300 bg-base-100 p-4">
          <h2 class="font-semibold">Definition</h2>
          <.list>
            <:item title="Module">{inspect(@agent.module)}</:item>
            <:item title="Loaded">{inspect(@agent.loaded?)}</:item>
            <:item title="Policy">{@agent.response_policy}</:item>
          </.list>
        </section>

        <section class="rounded-lg border border-base-300 bg-base-100 p-4">
          <h2 class="font-semibold">Room usage</h2>
          <p class="mt-2 text-sm opacity-70">
            The first implementation attaches this agent from a room settings page. It receives
            server-built context from the room, bridge, user, and message metadata, then posts
            its response back through `jido_messaging`.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Agents.get_agent(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Unknown agent")
         |> push_navigate(to: ~p"/agents")}

      agent ->
        {:ok,
         socket
         |> assign(:page_title, agent.name)
         |> assign(:agent, agent)}
    end
  end
end
