defmodule JidoChatUIWeb.RoomTimelineLive do
  @moduledoc """
  Nested Filament LiveView that owns the room timeline component tree.
  """

  use Filament.LiveView

  @impl true
  def mount(_params, session, socket) do
    socket =
      Phoenix.Component.assign(socket,
        room_id: session["room_id"],
        room_name: session["room_name"],
        current_user_email: session["current_user_email"]
      )

    super(%{}, session, socket)
  end

  @impl true
  def root_component, do: JidoChatUIWeb.Components.RoomTimeline
end
