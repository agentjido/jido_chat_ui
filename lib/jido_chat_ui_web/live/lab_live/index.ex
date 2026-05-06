defmodule JidoChatUIWeb.LabLive.Index do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Labs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Adapter Labs
        <:subtitle>Choose one adapter and walk it through the proof loop.</:subtitle>
      </.header>

      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <.link
          :for={lab <- @labs}
          navigate={~p"/labs/#{lab.adapter_id}"}
          class="rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="font-semibold">{lab.adapter.name}</p>
              <p class="mt-1 text-sm opacity-70">{lab.adapter.surface}</p>
            </div>
            <span class={["badge", readiness_badge(lab)]}>{readiness_text(lab)}</span>
          </div>
          <ol class="mt-4 space-y-1 text-sm">
            <li :for={step <- lab.steps} class="flex items-center gap-2">
              <span class={[
                "status",
                step.status == :done && "status-success",
                step.status != :done && "status-warning"
              ]} />
              <span>{step.label}</span>
            </li>
          </ol>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Adapter Labs")
     |> assign(:labs, Labs.list(scope: socket.assigns.current_scope))}
  end

  defp readiness_badge(%{health: %{status: :connected}, capability: %{status: :valid}}),
    do: "badge-success"

  defp readiness_badge(_lab), do: "badge-warning"

  defp readiness_text(%{health: %{status: :connected}, capability: %{status: :valid}}),
    do: "ready"

  defp readiness_text(_lab), do: "setup"
end
