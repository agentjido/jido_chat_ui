defmodule JidoChatUI.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias JidoChatUI.Repo

  alias JidoChatUI.Chat.{Room, RoomBridge}
  alias JidoChatUI.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any room changes.

  The broadcasted messages match the pattern:

    * {:created, %Room{}}
    * {:updated, %Room{}}
    * {:deleted, %Room{}}

  """
  def subscribe_rooms(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(JidoChatUI.PubSub, "user:#{key}:rooms")
  end

  defp broadcast_room(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(JidoChatUI.PubSub, "user:#{key}:rooms", message)
  end

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms(scope)
      [%Room{}, ...]

  """
  def list_rooms(%Scope{} = scope) do
    Repo.all_by(Room, user_id: scope.user.id)
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(scope, 123)
      %Room{}

      iex> get_room!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(%Scope{} = scope, id) do
    Repo.get_by!(Room, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(scope, %{field: value})
      {:ok, %Room{}}

      iex> create_room(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(%Scope{} = scope, attrs) do
    with {:ok, room = %Room{}} <-
           %Room{}
           |> Room.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_room(scope, {:created, room})
      {:ok, room}
    end
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(scope, room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(scope, room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Scope{} = scope, %Room{} = room, attrs) do
    true = room.user_id == scope.user.id

    with {:ok, room = %Room{}} <-
           room
           |> Room.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_room(scope, {:updated, room})
      {:ok, room}
    end
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(scope, room)
      {:ok, %Room{}}

      iex> delete_room(scope, room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Scope{} = scope, %Room{} = room) do
    true = room.user_id == scope.user.id

    with {:ok, room = %Room{}} <-
           Repo.delete(room) do
      broadcast_room(scope, {:deleted, room})
      {:ok, room}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(scope, room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Scope{} = scope, %Room{} = room, attrs \\ %{}) do
    true = room.user_id == scope.user.id

    Room.changeset(room, attrs, scope)
  end

  @doc """
  Subscribes to scoped notifications about any room_bridge changes.

  The broadcasted messages match the pattern:

    * {:created, %RoomBridge{}}
    * {:updated, %RoomBridge{}}
    * {:deleted, %RoomBridge{}}

  """
  def subscribe_room_bridges(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(JidoChatUI.PubSub, "user:#{key}:room_bridges")
  end

  defp broadcast_room_bridge(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(JidoChatUI.PubSub, "user:#{key}:room_bridges", message)
  end

  @doc """
  Returns the list of room_bridges.

  ## Examples

      iex> list_room_bridges(scope)
      [%RoomBridge{}, ...]

  """
  def list_room_bridges(%Scope{} = scope) do
    RoomBridge
    |> where([room_bridge], room_bridge.user_id == ^scope.user.id)
    |> order_by([room_bridge], desc: room_bridge.inserted_at)
    |> Repo.all()
  end

  def list_room_bridges_for_room(%Scope{} = scope, room_id) do
    RoomBridge
    |> where(
      [room_bridge],
      room_bridge.user_id == ^scope.user.id and room_bridge.room_id == ^room_id
    )
    |> order_by([room_bridge], desc: room_bridge.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single room_bridge.

  Raises `Ecto.NoResultsError` if the Room bridge does not exist.

  ## Examples

      iex> get_room_bridge!(scope, 123)
      %RoomBridge{}

      iex> get_room_bridge!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_room_bridge!(%Scope{} = scope, id) do
    Repo.get_by!(RoomBridge, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a room_bridge.

  ## Examples

      iex> create_room_bridge(scope, %{field: value})
      {:ok, %RoomBridge{}}

      iex> create_room_bridge(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room_bridge(%Scope{} = scope, attrs) do
    with {:ok, room_bridge = %RoomBridge{}} <-
           %RoomBridge{}
           |> RoomBridge.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_room_bridge(scope, {:created, room_bridge})
      {:ok, room_bridge}
    end
  end

  @doc """
  Updates a room_bridge.

  ## Examples

      iex> update_room_bridge(scope, room_bridge, %{field: new_value})
      {:ok, %RoomBridge{}}

      iex> update_room_bridge(scope, room_bridge, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room_bridge(%Scope{} = scope, %RoomBridge{} = room_bridge, attrs) do
    true = room_bridge.user_id == scope.user.id

    with {:ok, room_bridge = %RoomBridge{}} <-
           room_bridge
           |> RoomBridge.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_room_bridge(scope, {:updated, room_bridge})
      {:ok, room_bridge}
    end
  end

  @doc """
  Deletes a room_bridge.

  ## Examples

      iex> delete_room_bridge(scope, room_bridge)
      {:ok, %RoomBridge{}}

      iex> delete_room_bridge(scope, room_bridge)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room_bridge(%Scope{} = scope, %RoomBridge{} = room_bridge) do
    true = room_bridge.user_id == scope.user.id

    with {:ok, room_bridge = %RoomBridge{}} <-
           Repo.delete(room_bridge) do
      broadcast_room_bridge(scope, {:deleted, room_bridge})
      {:ok, room_bridge}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room_bridge changes.

  ## Examples

      iex> change_room_bridge(scope, room_bridge)
      %Ecto.Changeset{data: %RoomBridge{}}

  """
  def change_room_bridge(%Scope{} = scope, %RoomBridge{} = room_bridge, attrs \\ %{}) do
    true = room_bridge.user_id == scope.user.id

    RoomBridge.changeset(room_bridge, attrs, scope)
  end
end
