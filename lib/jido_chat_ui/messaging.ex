defmodule JidoChatUI.Messaging do
  @moduledoc """
  Local `jido_messaging` runtime used by the showcase UI.

  The spike starts with ETS persistence so the Phoenix screens can exercise the
  runtime contract immediately. The production path is a Postgres persistence
  adapter that implements `Jido.Messaging.Persistence`.
  """

  use Jido.Messaging,
    persistence: Jido.Messaging.Persistence.ETS,
    pubsub: JidoChatUI.PubSub
end
