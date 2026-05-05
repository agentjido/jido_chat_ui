defmodule JidoChatUI.AdaptersTest do
  use ExUnit.Case, async: true

  alias JidoChatUI.Adapters

  test "bundled adapters expose bridge configuration fields" do
    assert Enum.map(Adapters.select_options(), &elem(&1, 1)) == [
             "github",
             "slack",
             "telegram",
             "discord",
             "mattermost",
             "x"
           ]

    assert Enum.any?(Adapters.config_fields("github"), &(&1.key == "owner_repo"))
    assert Enum.any?(Adapters.config_fields("slack"), &(&1.key == "channel_id"))
    assert Enum.any?(Adapters.config_fields("x"), &(&1.key == "recipient_id"))
  end

  test "unknown adapters do not render custom config fields" do
    assert Adapters.config_fields(nil) == []
    assert Adapters.config_fields("") == []
    assert Adapters.config_fields("unknown") == []
  end

  test "telegram health is connected when the adapter is loaded and bot token is present" do
    status =
      "telegram"
      |> Adapters.get()
      |> Adapters.health_status(fn
        "TELEGRAM_BOT_TOKEN" -> "telegram-token"
        _key -> nil
      end)

    assert status.status == :connected
    assert status.short_name == "TG"
    assert status.missing_env == []
    assert status.title == "Telegram: connected"
  end

  test "telegram health asks for configuration when bot token is missing" do
    status =
      "telegram"
      |> Adapters.get()
      |> Adapters.health_status(fn _key -> nil end)

    assert status.status == :needs_config
    assert status.missing_env == ["TELEGRAM_BOT_TOKEN"]
    assert status.title == "Telegram: missing TELEGRAM_BOT_TOKEN"
  end

  test "mattermost health accepts either token env convention" do
    status =
      "mattermost"
      |> Adapters.get()
      |> Adapters.health_status(fn
        "MATTERMOST_BASE_URL" -> "https://mattermost.example.test"
        "MATTERMOST_BOT_TOKEN" -> "token"
        _key -> nil
      end)

    assert status.status == :connected
  end
end
