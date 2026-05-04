defmodule JidoChatUI.Bridges.Bridge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bridges" do
    field :name, :string
    field :adapter, :string
    field :status, :string, default: "draft"
    field :config, :map, default: %{}
    field :metadata, :map, default: %{}
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bridge, attrs, user_scope) do
    bridge
    |> cast(attrs, [:name, :adapter, :status, :config, :metadata])
    |> validate_required([:name, :adapter, :status])
    |> put_change(:user_id, user_scope.user.id)
  end
end
