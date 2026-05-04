defmodule JidoChatUIWeb.RoomLive.Form do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat
  alias JidoChatUI.Chat.Room

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage room records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="room-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[{"Draft", "draft"}, {"Active", "active"}, {"Paused", "paused"}]}
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Room</.button>
          <.button navigate={return_path(@current_scope, @return_to, @room)}>Cancel</.button>
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
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    room = Chat.get_room!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Room")
    |> assign(:room, room)
    |> assign(:form, to_form(Chat.change_room(socket.assigns.current_scope, room)))
  end

  defp apply_action(socket, :new, _params) do
    room = %Room{user_id: socket.assigns.current_scope.user.id, status: "draft", metadata: %{}}

    socket
    |> assign(:page_title, "New Room")
    |> assign(:room, room)
    |> assign(:form, to_form(Chat.change_room(socket.assigns.current_scope, room)))
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Chat.change_room(socket.assigns.current_scope, socket.assigns.room, room_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"room" => room_params}, socket) do
    save_room(socket, socket.assigns.live_action, room_params)
  end

  defp save_room(socket, :edit, room_params) do
    case Chat.update_room(socket.assigns.current_scope, socket.assigns.room, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, room)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_room(socket, :new, room_params) do
    case Chat.create_room(socket.assigns.current_scope, room_params) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, room)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _room), do: ~p"/rooms"
  defp return_path(_scope, "show", room), do: ~p"/rooms/#{room}"
end
