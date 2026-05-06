defmodule JidoChatUIWeb.PageController do
  use JidoChatUIWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/setup")
  end
end
