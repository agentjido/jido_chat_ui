defmodule JidoChatUI.Chat.RoomBridge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "room_bridges" do
    field :external_room_id, :string
    field :external_thread_id, :string
    field :status, :string, default: "draft"
    field :metadata, :map, default: %{}
    field :room_id, :id
    field :bridge_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room_bridge, attrs, user_scope) do
    room_bridge
    |> cast(attrs, [
      :room_id,
      :bridge_id,
      :external_room_id,
      :external_thread_id,
      :status,
      :metadata
    ])
    |> validate_required([:room_id, :bridge_id, :external_room_id, :status])
    |> put_change(:user_id, user_scope.user.id)
  end
end
