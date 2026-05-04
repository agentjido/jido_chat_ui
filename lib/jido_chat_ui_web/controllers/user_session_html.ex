defmodule JidoChatUIWeb.UserSessionHTML do
  use JidoChatUIWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:jido_chat_ui, JidoChatUI.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
