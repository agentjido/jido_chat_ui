defmodule JidoChatUIWeb.GuideLiveTest do
  use JidoChatUIWeb.ConnCase

  import Phoenix.LiveViewTest

  test "guides index surfaces onboarding and adapter setup", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/guides")

    assert html =~ "Interactive setup docs"
    assert html =~ "Getting Started"
    assert html =~ "Onboarding And Scope"
    assert html =~ "Adapter Setup"
    assert html =~ "GitHub"
  end

  test "onboarding scope guide renders the review baseline", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/guides/onboarding-scope")

    assert html =~ "Jido Chat UI Onboarding And Scope"
    assert html =~ "Gap Analysis Template"
    assert html =~ "Create adapter lab room"
  end

  test "adapter guide renders markdown with live setup context", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/guides/adapters/telegram")

    assert html =~ "Telegram Adapter"
    assert html =~ "Adapter Status"
    assert html =~ "TELEGRAM_BOT_TOKEN"
    assert html =~ "Create a bridge"
  end

  test "signal guide stays available through its legacy route", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/guides/signal")

    assert html =~ "Signal Adapter"
    assert html =~ "optional in"
    assert html =~ "jido_chat_signal"
  end
end
