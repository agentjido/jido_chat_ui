defmodule JidoChatUIWeb.BridgeLive.Form do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Bridges
  alias JidoChatUI.Bridges.Bridge

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage bridge records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="bridge-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:adapter]}
          type="select"
          label="Adapter"
          prompt="Choose an adapter"
          options={@adapter_options}
        />
        <.input field={@form[:status]} type="text" label="Status" />

        <section
          :if={@adapter_guide}
          class="my-4 flex items-start justify-between gap-4 rounded-lg border border-base-300 bg-base-100 p-4"
        >
          <div>
            <h2 class="text-sm font-semibold">Setup guide</h2>
            <p class="mt-1 text-sm opacity-70">
              {@adapter_guide.summary}
            </p>
          </div>
          <.link navigate={@adapter_guide.route} class="btn btn-sm btn-outline">
            Open
          </.link>
        </section>

        <section
          :if={@config_fields != []}
          class="my-4 rounded-lg border border-base-300 bg-base-200/40 p-4"
        >
          <h2 class="text-sm font-semibold">Adapter config</h2>
          <p class="mt-1 text-sm opacity-70">
            Store stable room and env-var names here. Put actual secrets in `.env`.
          </p>
          <div class="mt-4 grid gap-3 md:grid-cols-2">
            <.input
              :for={field <- @config_fields}
              type="text"
              id={"bridge_config_#{field.key}"}
              name={"bridge[config][#{field.key}]"}
              label={field.label}
              value={config_value(@form, field.key)}
              placeholder={field.placeholder}
            />
          </div>
        </section>

        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Bridge</.button>
          <.button navigate={return_path(@current_scope, @return_to, @bridge)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(:adapter_options, JidoChatUI.Adapters.select_options())
     |> assign(:config_fields, [])
     |> assign(:adapter_guide, nil)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    bridge = Bridges.get_bridge!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Bridge")
    |> assign(:bridge, bridge)
    |> assign(:config_fields, JidoChatUI.Adapters.config_fields(bridge.adapter))
    |> assign(:adapter_guide, JidoChatUI.Docs.adapter_guide(bridge.adapter))
    |> assign(:form, to_form(Bridges.change_bridge(socket.assigns.current_scope, bridge)))
  end

  defp apply_action(socket, :new, _params) do
    bridge = %Bridge{user_id: socket.assigns.current_scope.user.id, status: "draft"}

    socket
    |> assign(:page_title, "New Bridge")
    |> assign(:bridge, bridge)
    |> assign(:config_fields, [])
    |> assign(:adapter_guide, nil)
    |> assign(:form, to_form(Bridges.change_bridge(socket.assigns.current_scope, bridge)))
  end

  @impl true
  def handle_event("validate", %{"bridge" => bridge_params}, socket) do
    adapter = Map.get(bridge_params, "adapter")

    changeset =
      Bridges.change_bridge(socket.assigns.current_scope, socket.assigns.bridge, bridge_params)

    {:noreply,
     socket
     |> assign(:config_fields, JidoChatUI.Adapters.config_fields(adapter))
     |> assign(:adapter_guide, JidoChatUI.Docs.adapter_guide(adapter || ""))
     |> assign(form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"bridge" => bridge_params}, socket) do
    save_bridge(socket, socket.assigns.live_action, bridge_params)
  end

  defp save_bridge(socket, :edit, bridge_params) do
    case Bridges.update_bridge(socket.assigns.current_scope, socket.assigns.bridge, bridge_params) do
      {:ok, bridge} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bridge updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, bridge)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_bridge(socket, :new, bridge_params) do
    case Bridges.create_bridge(socket.assigns.current_scope, bridge_params) do
      {:ok, bridge} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bridge created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, bridge)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _bridge), do: ~p"/bridges"
  defp return_path(_scope, "show", bridge), do: ~p"/bridges/#{bridge}"

  defp config_value(%Phoenix.HTML.Form{} = form, key) do
    params = form.params || %{}
    changeset = form.source
    config = Ecto.Changeset.get_field(changeset, :config, %{}) || %{}

    get_in(params, ["config", key]) || Map.get(config, key) || ""
  end
end
