defmodule JidoChatUI.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "draft"
    field :metadata, :map, default: %{}
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs, user_scope) do
    room
    |> cast(attrs, [:name, :description, :status, :metadata])
    |> validate_required([:name, :status])
    |> put_change(:user_id, user_scope.user.id)
  end
end
