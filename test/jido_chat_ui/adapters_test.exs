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
end
