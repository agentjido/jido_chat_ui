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
    |> update_change(:config, &normalize_config/1)
    |> validate_required([:name, :adapter, :status])
    |> put_change(:user_id, user_scope.user.id)
  end

  defp normalize_config(config) when is_map(config) do
    config
    |> Enum.reduce(%{}, fn
      {_key, value}, acc when value in [nil, ""] ->
        acc

      {key, value}, acc when is_binary(value) ->
        value = String.trim(value)

        if value == "" do
          acc
        else
          Map.put(acc, key, value)
        end

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp normalize_config(config), do: config
end
