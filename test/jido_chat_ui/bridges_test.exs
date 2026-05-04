defmodule JidoChatUI.BridgesTest do
  use JidoChatUI.DataCase

  alias JidoChatUI.Bridges

  describe "bridges" do
    alias JidoChatUI.Bridges.Bridge

    import JidoChatUI.AccountsFixtures, only: [user_scope_fixture: 0]
    import JidoChatUI.BridgesFixtures

    @invalid_attrs %{name: nil, status: nil, config: nil, metadata: nil, adapter: nil}

    test "list_bridges/1 returns all scoped bridges" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      other_bridge = bridge_fixture(other_scope)
      assert Bridges.list_bridges(scope) == [bridge]
      assert Bridges.list_bridges(other_scope) == [other_bridge]
    end

    test "get_bridge!/2 returns the bridge with given id" do
      scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      other_scope = user_scope_fixture()
      assert Bridges.get_bridge!(scope, bridge.id) == bridge
      assert_raise Ecto.NoResultsError, fn -> Bridges.get_bridge!(other_scope, bridge.id) end
    end

    test "create_bridge/2 with valid data creates a bridge" do
      valid_attrs = %{
        name: "some name",
        status: "some status",
        config: %{},
        metadata: %{},
        adapter: "some adapter"
      }

      scope = user_scope_fixture()

      assert {:ok, %Bridge{} = bridge} = Bridges.create_bridge(scope, valid_attrs)
      assert bridge.name == "some name"
      assert bridge.status == "some status"
      assert bridge.config == %{}
      assert bridge.metadata == %{}
      assert bridge.adapter == "some adapter"
      assert bridge.user_id == scope.user.id
    end

    test "create_bridge/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Bridges.create_bridge(scope, @invalid_attrs)
    end

    test "update_bridge/3 with valid data updates the bridge" do
      scope = user_scope_fixture()
      bridge = bridge_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        status: "some updated status",
        config: %{},
        metadata: %{},
        adapter: "some updated adapter"
      }

      assert {:ok, %Bridge{} = bridge} = Bridges.update_bridge(scope, bridge, update_attrs)
      assert bridge.name == "some updated name"
      assert bridge.status == "some updated status"
      assert bridge.config == %{}
      assert bridge.metadata == %{}
      assert bridge.adapter == "some updated adapter"
    end

    test "update_bridge/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      bridge = bridge_fixture(scope)

      assert_raise MatchError, fn ->
        Bridges.update_bridge(other_scope, bridge, %{})
      end
    end

    test "update_bridge/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Bridges.update_bridge(scope, bridge, @invalid_attrs)
      assert bridge == Bridges.get_bridge!(scope, bridge.id)
    end

    test "delete_bridge/2 deletes the bridge" do
      scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      assert {:ok, %Bridge{}} = Bridges.delete_bridge(scope, bridge)
      assert_raise Ecto.NoResultsError, fn -> Bridges.get_bridge!(scope, bridge.id) end
    end

    test "delete_bridge/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      assert_raise MatchError, fn -> Bridges.delete_bridge(other_scope, bridge) end
    end

    test "change_bridge/2 returns a bridge changeset" do
      scope = user_scope_fixture()
      bridge = bridge_fixture(scope)
      assert %Ecto.Changeset{} = Bridges.change_bridge(scope, bridge)
    end
  end
end
