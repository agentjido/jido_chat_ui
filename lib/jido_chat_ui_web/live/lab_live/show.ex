defmodule JidoChatUIWeb.LabLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Labs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_room_id={@lab.room && @lab.room.id}
    >
      <.header>
        {@lab.adapter.name} Lab
        <:subtitle>
          Prove one adapter with a room, bridge, binding, smoke messages, and inspection.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/labs"}><.icon name="hero-arrow-left" /> Labs</.button>
          <.button :if={@lab.room} variant="primary" navigate={~p"/rooms/#{@lab.room}"}>
            Open room
          </.button>
        </:actions>
      </.header>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="space-y-4">
          <div class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Proof Checklist</h2>
            <div class="mt-4 space-y-2">
              <div :for={step <- @lab.steps} class="flex items-start gap-3 rounded bg-base-200/50 p-3">
                <span class={[
                  "status mt-1",
                  step_status_class(step.status)
                ]} />
                <div class="min-w-0">
                  <p class="font-medium">{step.label}</p>
                  <p class="mt-1 break-words text-sm opacity-70">{step.detail}</p>
                </div>
              </div>
            </div>
          </div>

          <div class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Create Or Reuse Lab Objects</h2>
            <p class="mt-1 text-sm opacity-70">
              This creates one lab room, one bridge, and an active binding when a target is present.
              Secrets stay in `.env`.
            </p>
            <.form for={%{}} as={:lab} id="lab-form" phx-submit="ensure_lab" class="mt-4">
              <.input
                type="text"
                name="lab[external_room_id]"
                value={@lab.target}
                label="External target"
                placeholder={Labs.target_env(@lab.adapter_id) || "provider target id"}
              />
              <.button variant="primary" phx-disable-with="Preparing...">Prepare lab</.button>
            </.form>
          </div>
        </section>

        <aside class="space-y-4">
          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Adapter</h2>
            <.list>
              <:item title="Package">{if @lab.adapter.loaded?, do: "loaded", else: "missing"}</:item>
              <:item title="Config">{@lab.health.title}</:item>
              <:item title="Capabilities">{@lab.capability.detail}</:item>
            </.list>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Lab Objects</h2>
            <.list>
              <:item title="Room">{object_label(@lab.room)}</:item>
              <:item title="Bridge">{object_label(@lab.bridge)}</:item>
              <:item title="Binding">{binding_label(@lab.binding)}</:item>
              <:item title="Target">{blank_label(@lab.target)}</:item>
            </.list>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Next Actions</h2>
            <div class="mt-3 space-y-2">
              <.link :if={@lab.room} navigate={~p"/rooms/#{@lab.room}"} class="btn btn-sm w-full">
                Open room and send a message
              </.link>
              <.link
                navigate={~p"/guides/adapters/#{@lab.adapter_id}"}
                class="btn btn-sm btn-outline w-full"
              >
                Open adapter guide
              </.link>
              <.link navigate={~p"/ops"} class="btn btn-sm btn-ghost w-full">Open ops</.link>
            </div>
          </section>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"adapter" => adapter_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:adapter_id, adapter_id)
     |> assign_lab()}
  end

  @impl true
  def handle_event("ensure_lab", %{"lab" => params}, socket) do
    case Labs.ensure_lab(socket.assigns.adapter_id, params, scope: socket.assigns.current_scope) do
      {:ok, lab} ->
        {:noreply,
         socket
         |> assign(:lab, lab)
         |> assign(:page_title, "#{lab.adapter.name} Lab")
         |> put_flash(:info, "Lab is ready.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Lab setup failed: #{inspect(reason)}")}
    end
  end

  defp assign_lab(socket) do
    lab = Labs.state(socket.assigns.adapter_id, scope: socket.assigns.current_scope)

    socket
    |> assign(:page_title, "#{lab.adapter.name} Lab")
    |> assign(:lab, lab)
  end

  defp object_label(nil), do: "Not created"
  defp object_label(%{name: name, id: id}), do: "#{name} (#{id})"
  defp binding_label(nil), do: "Not bound"
  defp binding_label(binding), do: "#{binding.external_room_id} (#{binding.status})"
  defp blank_label(value) when value in [nil, ""], do: "Not set"
  defp blank_label(value), do: value
  defp step_status_class(:done), do: "status-success"
  defp step_status_class(:failed), do: "status-error"
  defp step_status_class(_status), do: "status-warning"
end
