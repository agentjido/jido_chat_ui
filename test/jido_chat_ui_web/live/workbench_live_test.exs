defmodule JidoChatUIWeb.WorkbenchLiveTest do
  use JidoChatUIWeb.ConnCase

  import Phoenix.LiveViewTest

  alias JidoChatUI.{Labs, Messaging, Workspace}

  test "setup dashboard works without login and exposes adapter readiness", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/setup")

    assert html =~ "Adapter Workbench"
    assert html =~ "Adapter Readiness"
    assert html =~ "GitHub"
    assert html =~ "Telegram"
    refute html =~ "/users/log-in"
    refute html =~ "/users/register"
  end

  test "labs index works without login and excludes optional Signal", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/labs")

    assert html =~ "Adapter Labs"
    assert html =~ "GitHub"
    assert html =~ "Telegram"
    refute html =~ ~s(href="/labs/signal")
  end

  test "setup dashboard surfaces failed adapter smoke checks", %{conn: conn} do
    scope = Workspace.scope!()

    assert {:ok, lab} =
             Labs.ensure_lab(
               "telegram",
               %{"external_room_id" => "telegram-live-test"},
               scope: scope,
               env_fun: fn _key -> nil end
             )

    assert {:ok, _message} =
             Messaging.save_message(%{
               room_id: to_string(lab.room.id),
               sender_id: "ui:user:test",
               role: :user,
               content: [%{type: :text, text: "failed smoke"}],
               status: :failed,
               metadata: %{
                 "source" => "ui",
                 "route_decision" => "delivery_failed",
                 "failed_routes" => [%{"reason" => "Bad Request: chat not found"}]
               }
             })

    {:ok, _live, html} = live(conn, ~p"/setup")

    assert html =~ "failing"
    assert html =~ "Outbound smoke"
  end

  test "lab show prepares a scoped room, bridge, and binding", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/labs/telegram")

    assert html =~ "Telegram Lab"
    assert html =~ "Proof Checklist"

    html =
      live
      |> form("#lab-form", lab: %{external_room_id: "telegram-live-test"})
      |> render_submit()

    assert html =~ "Lab is ready."
    assert html =~ "telegram-live-test"
    assert html =~ "Open room and send a message"
  end

  test "advanced routes no longer redirect to login", %{conn: conn} do
    for path <- [~p"/rooms", ~p"/bridges", ~p"/agents", ~p"/ops", ~p"/guides"] do
      {:ok, _live, html} = live(conn, path)
      refute html =~ "/users/log-in"
    end
  end
end
