defmodule JidoChatUIWeb.AgentLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Agents
        <:subtitle>Jidoka responders that can be attached to rooms.</:subtitle>
      </.header>

      <div class="grid gap-4 md:grid-cols-2">
        <.link
          :for={agent <- @agents}
          navigate={~p"/agents/#{agent.id}"}
          class="rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="font-medium">{agent.name}</p>
              <p class="mt-1 text-sm opacity-70">{agent.description}</p>
            </div>
            <span class={[
              "badge",
              agent.loaded? && "badge-success",
              !agent.loaded? && "badge-warning"
            ]}>
              {if agent.loaded?, do: "loaded", else: "missing"}
            </span>
          </div>
          <p class="mt-3 text-xs opacity-60">Policy: {agent.response_policy}</p>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Agents")
     |> assign(:agents, Agents.list_agents())}
  end
end
