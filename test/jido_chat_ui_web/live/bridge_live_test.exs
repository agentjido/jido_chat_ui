defmodule JidoChatUIWeb.BridgeLiveTest do
  use JidoChatUIWeb.ConnCase

  import Phoenix.LiveViewTest
  import JidoChatUI.BridgesFixtures

  alias JidoChatUI.Bridges

  @create_attrs %{
    name: "some name",
    status: "draft",
    adapter: "github"
  }
  @update_attrs %{
    name: "some updated name",
    status: "active",
    adapter: "slack"
  }
  @invalid_attrs %{name: nil, status: nil, adapter: ""}

  setup :register_and_log_in_user

  defp create_bridge(%{scope: scope}) do
    bridge = bridge_fixture(scope)

    %{bridge: bridge}
  end

  describe "Index" do
    setup [:create_bridge]

    test "lists all bridges", %{conn: conn, bridge: bridge} do
      {:ok, _index_live, html} = live(conn, ~p"/bridges")

      assert html =~ "Listing Bridges"
      assert html =~ bridge.name
    end

    test "saves new bridge", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/bridges")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Bridge")
               |> render_click()
               |> follow_redirect(conn, ~p"/bridges/new")

      assert render(form_live) =~ "New Bridge"

      assert form_live
             |> form("#bridge-form", bridge: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#bridge-form", bridge: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/bridges")

      html = render(index_live)
      assert html =~ "Bridge created successfully"
      assert html =~ "some name"
    end

    test "saves adapter config from the bridge form", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} = live(conn, ~p"/bridges/new")

      html =
        form_live
        |> form("#bridge-form",
          bridge: %{name: "repo bridge", status: "draft", adapter: "github"}
        )
        |> render_change()

      assert html =~ "Adapter config"
      assert html =~ "Owner/repo"
      assert html =~ "Token env"

      attrs = %{
        name: "repo bridge",
        status: "draft",
        adapter: "github",
        config: %{
          "owner_repo" => " agentjido/jido_chat_ui ",
          "issue_number" => "",
          "token_env" => " GITHUB_TOKEN "
        }
      }

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#bridge-form", bridge: attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/bridges")

      bridge = Enum.find(Bridges.list_bridges(scope), &(&1.name == "repo bridge"))

      assert bridge

      assert bridge.config == %{
               "owner_repo" => "agentjido/jido_chat_ui",
               "token_env" => "GITHUB_TOKEN"
             }
    end

    test "updates bridge in listing", %{conn: conn, bridge: bridge} do
      {:ok, index_live, _html} = live(conn, ~p"/bridges")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#bridges-#{bridge.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/bridges/#{bridge}/edit")

      assert render(form_live) =~ "Edit Bridge"

      assert form_live
             |> form("#bridge-form", bridge: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#bridge-form", bridge: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/bridges")

      html = render(index_live)
      assert html =~ "Bridge updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes bridge in listing", %{conn: conn, bridge: bridge} do
      {:ok, index_live, _html} = live(conn, ~p"/bridges")

      assert index_live |> element("#bridges-#{bridge.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#bridges-#{bridge.id}")
    end
  end

  describe "Show" do
    setup [:create_bridge]

    test "displays bridge", %{conn: conn, bridge: bridge} do
      {:ok, _show_live, html} = live(conn, ~p"/bridges/#{bridge}")

      assert html =~ "Show Bridge"
      assert html =~ bridge.name
    end

    test "updates bridge and returns to show", %{conn: conn, bridge: bridge} do
      {:ok, show_live, _html} = live(conn, ~p"/bridges/#{bridge}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/bridges/#{bridge}/edit?return_to=show")

      assert render(form_live) =~ "Edit Bridge"

      assert form_live
             |> form("#bridge-form", bridge: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#bridge-form", bridge: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/bridges/#{bridge}")

      html = render(show_live)
      assert html =~ "Bridge updated successfully"
      assert html =~ "some updated name"
    end
  end
end
