defmodule JidoChatUIWeb.PageControllerTest do
  use JidoChatUIWeb.ConnCase

  test "GET / redirects to setup", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/setup"
  end
end
