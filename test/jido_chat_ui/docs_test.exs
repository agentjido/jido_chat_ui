defmodule JidoChatUI.DocsTest do
  use ExUnit.Case, async: true

  alias JidoChatUI.Docs

  test "workflow guides are backed by rendered markdown" do
    guide = Docs.get!("getting-started")

    assert guide.title == "Getting Started"
    assert guide.route == "/guides/getting-started"
    assert Docs.to_html!(guide) =~ "<h1>Getting Started</h1>"

    scope = Docs.get!("onboarding-scope")
    assert scope.route == "/guides/onboarding-scope"
    assert Docs.to_html!(scope) =~ "Gap Analysis Template"
  end

  test "adapter guides expose provider route metadata" do
    adapter_ids =
      Docs.adapter_guides()
      |> Enum.map(& &1.adapter_id)

    assert "telegram" in adapter_ids
    assert Docs.adapter_guide("github").route == "/guides/adapters/github"
    assert Docs.adapter_guide("signal").route == "/guides/signal"
  end
end
