defmodule JidoChatUIWeb.SetupLive do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.{Labs, Messaging}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Adapter Workbench
        <:subtitle>Pick one adapter, prove it, inspect what happened, then add an agent.</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/labs"}>Open Labs</.button>
        </:actions>
      </.header>

      <section class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <.status_card
          title="Database"
          value="Postgres"
          detail="Workspace data and jido_messaging persistence"
          status={:done}
        />
        <.status_card title="Messaging" value="Running" detail={inspect(@signal_bus)} status={:done} />
        <.status_card
          title="Workspace"
          value="Local"
          detail={@current_scope.user.email}
          status={:done}
        />
        <.status_card
          title="Secrets"
          value=".env"
          detail="Provider keys stay out of the UI"
          status={:done}
        />
      </section>

      <section class="space-y-3">
        <div class="flex items-center justify-between gap-3">
          <div>
            <h2 class="text-base font-semibold">Adapter Readiness</h2>
            <p class="text-sm opacity-70">
              Start with one adapter. Labs create or reuse the backing room, bridge, and binding.
            </p>
          </div>
          <.link navigate={~p"/guides/adapters"} class="btn btn-sm btn-outline">Guides</.link>
        </div>

        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <.adapter_card :for={lab <- @labs} lab={lab} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true
  attr :status, :atom, required: true

  defp status_card(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-300 bg-base-100 p-4">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-sm font-medium opacity-70">{@title}</p>
          <p class="mt-2 truncate text-xl font-semibold">{@value}</p>
        </div>
        <span class={["badge shrink-0 px-3", status_badge_class(@status)]}>
          {status_text(@status)}
        </span>
      </div>
      <p class="mt-3 line-clamp-2 text-xs leading-relaxed opacity-60">{@detail}</p>
    </section>
    """
  end

  attr :lab, :map, required: true

  defp adapter_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/labs/#{@lab.adapter_id}"}
      class="block rounded-lg border border-base-300 bg-base-100 p-4 transition hover:border-base-content/30 hover:bg-base-200"
    >
      <div class="grid min-h-20 grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
        <div class="min-w-0">
          <p class="font-semibold">{@lab.adapter.name}</p>
          <p class="mt-1 line-clamp-2 text-sm leading-relaxed opacity-70">
            {@lab.adapter.surface}
          </p>
        </div>
        <span class={[
          "badge min-w-20 shrink-0 whitespace-nowrap px-3",
          adapter_badge_class(@lab)
        ]}>
          {adapter_status_text(@lab)}
        </span>
      </div>

      <div class="mt-4 grid gap-x-4 gap-y-2 text-xs sm:grid-cols-2">
        <span :for={step <- adapter_visible_steps(@lab)} class="flex min-w-0 items-center gap-2">
          <span class={[
            "status status-xs shrink-0",
            step_status_class(step.status)
          ]} />
          <span class="truncate">{step.label}</span>
        </span>
      </div>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Adapter Workbench")
     |> assign(:signal_bus, Jido.Messaging.Supervisor.signal_bus_name(Messaging))
     |> assign(:labs, Labs.list(scope: socket.assigns.current_scope))}
  end

  defp adapter_badge_class(lab) do
    cond do
      lab_failed?(lab) ->
        "badge-error"

      match?(%{adapter: %{loaded?: false}}, lab) ->
        "badge-error"

      match?(%{health: %{status: :connected}, capability: %{status: :valid}}, lab) ->
        "badge-success"

      true ->
        "badge-warning"
    end
  end

  defp adapter_status_text(lab) do
    cond do
      lab_failed?(lab) -> "failing"
      match?(%{adapter: %{loaded?: false}}, lab) -> "missing"
      match?(%{health: %{status: :connected}, capability: %{status: :valid}}, lab) -> "ready"
      true -> "needs setup"
    end
  end

  defp adapter_visible_steps(lab) do
    failed_steps = Enum.filter(lab.steps, &(&1.status == :failed))
    normal_steps = Enum.reject(lab.steps, &(&1.status == :failed))

    (failed_steps ++ normal_steps)
    |> Enum.take(8)
  end

  defp lab_failed?(lab), do: Enum.any?(lab.steps, &(&1.status == :failed))

  defp step_status_class(:done), do: "status-success"
  defp step_status_class(:failed), do: "status-error"
  defp step_status_class(_status), do: "status-warning"

  defp status_badge_class(:done), do: "badge-success"
  defp status_badge_class(_status), do: "badge-warning"

  defp status_text(:done), do: "ok"
  defp status_text(_status), do: "check"
end
