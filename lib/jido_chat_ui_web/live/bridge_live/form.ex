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
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    bridge = Bridges.get_bridge!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Bridge")
    |> assign(:bridge, bridge)
    |> assign(:form, to_form(Bridges.change_bridge(socket.assigns.current_scope, bridge)))
  end

  defp apply_action(socket, :new, _params) do
    bridge = %Bridge{user_id: socket.assigns.current_scope.user.id, status: "draft"}

    socket
    |> assign(:page_title, "New Bridge")
    |> assign(:bridge, bridge)
    |> assign(:form, to_form(Bridges.change_bridge(socket.assigns.current_scope, bridge)))
  end

  @impl true
  def handle_event("validate", %{"bridge" => bridge_params}, socket) do
    changeset =
      Bridges.change_bridge(socket.assigns.current_scope, socket.assigns.bridge, bridge_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
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
end
