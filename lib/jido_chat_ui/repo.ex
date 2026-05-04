defmodule JidoChatUI.Repo do
  use Ecto.Repo,
    otp_app: :jido_chat_ui,
    adapter: Ecto.Adapters.Postgres
end
