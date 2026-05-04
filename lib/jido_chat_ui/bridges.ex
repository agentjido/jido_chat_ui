defmodule JidoChatUI.Bridges do
  @moduledoc """
  The Bridges context.
  """

  import Ecto.Query, warn: false
  alias JidoChatUI.Repo

  alias JidoChatUI.Bridges.Bridge
  alias JidoChatUI.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any bridge changes.

  The broadcasted messages match the pattern:

    * {:created, %Bridge{}}
    * {:updated, %Bridge{}}
    * {:deleted, %Bridge{}}

  """
  def subscribe_bridges(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(JidoChatUI.PubSub, "user:#{key}:bridges")
  end

  defp broadcast_bridge(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(JidoChatUI.PubSub, "user:#{key}:bridges", message)
  end

  @doc """
  Returns the list of bridges.

  ## Examples

      iex> list_bridges(scope)
      [%Bridge{}, ...]

  """
  def list_bridges(%Scope{} = scope) do
    Bridge
    |> where([bridge], bridge.user_id == ^scope.user.id)
    |> order_by([bridge], desc: bridge.inserted_at)
    |> Repo.all()
  end

  def bridge_options(%Scope{} = scope) do
    scope
    |> list_bridges()
    |> Enum.map(&{&1.name, &1.id})
  end

  @doc """
  Gets a single bridge.

  Raises `Ecto.NoResultsError` if the Bridge does not exist.

  ## Examples

      iex> get_bridge!(scope, 123)
      %Bridge{}

      iex> get_bridge!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_bridge!(%Scope{} = scope, id) do
    Repo.get_by!(Bridge, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a bridge.

  ## Examples

      iex> create_bridge(scope, %{field: value})
      {:ok, %Bridge{}}

      iex> create_bridge(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bridge(%Scope{} = scope, attrs) do
    with {:ok, bridge = %Bridge{}} <-
           %Bridge{}
           |> Bridge.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_bridge(scope, {:created, bridge})
      {:ok, bridge}
    end
  end

  @doc """
  Updates a bridge.

  ## Examples

      iex> update_bridge(scope, bridge, %{field: new_value})
      {:ok, %Bridge{}}

      iex> update_bridge(scope, bridge, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_bridge(%Scope{} = scope, %Bridge{} = bridge, attrs) do
    true = bridge.user_id == scope.user.id

    with {:ok, bridge = %Bridge{}} <-
           bridge
           |> Bridge.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_bridge(scope, {:updated, bridge})
      {:ok, bridge}
    end
  end

  @doc """
  Deletes a bridge.

  ## Examples

      iex> delete_bridge(scope, bridge)
      {:ok, %Bridge{}}

      iex> delete_bridge(scope, bridge)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bridge(%Scope{} = scope, %Bridge{} = bridge) do
    true = bridge.user_id == scope.user.id

    with {:ok, bridge = %Bridge{}} <-
           Repo.delete(bridge) do
      broadcast_bridge(scope, {:deleted, bridge})
      {:ok, bridge}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bridge changes.

  ## Examples

      iex> change_bridge(scope, bridge)
      %Ecto.Changeset{data: %Bridge{}}

  """
  def change_bridge(%Scope{} = scope, %Bridge{} = bridge, attrs \\ %{}) do
    true = bridge.user_id == scope.user.id

    Bridge.changeset(bridge, attrs, scope)
  end
end
