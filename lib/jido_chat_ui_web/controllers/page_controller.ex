defmodule JidoChatUIWeb.PageController do
  use JidoChatUIWeb, :controller

  def home(%{assigns: %{current_scope: %{user: _user}}} = conn, _params) do
    redirect(conn, to: ~p"/rooms")
  end

  def home(conn, _params) do
    render(conn, :home)
  end
end
