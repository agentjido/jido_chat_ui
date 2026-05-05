defmodule JidoChatUI.Messaging do
  @moduledoc """
  Local `jido_messaging` runtime used by the showcase UI.

  The UI uses the same Postgres-backed `Jido.Messaging.Persistence` contract
  that adapter ingress, outbound routing, room bindings, and bridge control
  plane code use in production.
  """

  use Jido.Messaging,
    persistence: JidoChatUI.Messaging.Persistence.Postgres,
    persistence_opts: [repo: JidoChatUI.Repo],
    pubsub: JidoChatUI.PubSub
end
