defmodule JidoChatUI.BridgesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `JidoChatUI.Bridges` context.
  """

  @doc """
  Generate a bridge.
  """
  def bridge_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        adapter: "github",
        config: %{},
        metadata: %{},
        name: "some name",
        status: "draft"
      })

    {:ok, bridge} = JidoChatUI.Bridges.create_bridge(scope, attrs)
    bridge
  end
end
