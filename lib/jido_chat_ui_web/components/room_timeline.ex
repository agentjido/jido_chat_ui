defmodule JidoChatUIWeb.Components.RoomTimeline do
  @moduledoc """
  Filament-backed room timeline.
  """

  use Filament.Component

  alias JidoChatUI.RoomTimeline

  defcomponent do
    prop(:room_id, :any, required: true)
    prop(:room_name, :string, required: true)

    def render(%{room_id: room_id, room_name: room_name}) do
      {_server, state} =
        use_observable(
          fn -> RoomTimeline.ensure_started(room_id, room_name) end,
          disconnected: RoomTimeline.disconnected_state(room_id, room_name)
        )

      {filter, set_filter} = use_state("all")

      messages = visible_messages(state.messages, filter)

      ~F"""
      <div>
        <div class="flex items-start justify-between gap-4 border-b border-base-300 px-4 py-3">
          <div>
            <h2 class="font-semibold">Timeline</h2>
            <p class="text-sm opacity-70">Filament observable timeline for {state.room_name}</p>
          </div>
          <div class="flex gap-1">
            <button type="button" class={filter_class(filter, "all")} on_click={fn -> set_filter.("all") end}>All</button>
            <button type="button" class={filter_class(filter, "ui")} on_click={fn -> set_filter.("ui") end}>UI</button>
            <button type="button" class={filter_class(filter, "adapter")} on_click={fn -> set_filter.("adapter") end}>Adapters</button>
          </div>
        </div>

        <div class="max-h-[28rem] space-y-3 overflow-y-auto p-4">
          {if messages == [] do}
            <div class="rounded-lg border border-dashed border-base-300 p-6 text-sm opacity-70">
              No messages match this filter.
            </div>
          {end}

          {for message <- messages do}
            <article class={message_class(message)} data-message-id={message.id}>
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-sm font-medium">{message.author}</p>
                  <p class="mt-1 whitespace-pre-wrap text-sm opacity-85">{message.body}</p>
                </div>
                <span class="shrink-0 rounded border border-base-300 px-2 py-0.5 text-xs opacity-70">
                  {message.status}
                </span>
              </div>
              <div class="mt-2 flex flex-wrap gap-2 text-xs opacity-60">
                <span>{message.source}</span>
                <span>{format_time(message.at)}</span>
              </div>
            </article>
          {end}
        </div>
      </div>
      """
    end

    defp visible_messages(messages, "all"), do: messages

    defp visible_messages(messages, "adapter"),
      do: Enum.reject(messages, &(&1.source in ["ui", "system"]))

    defp visible_messages(messages, source), do: Enum.filter(messages, &(&1.source == source))

    defp filter_class(current, current), do: "btn btn-xs btn-primary"
    defp filter_class(_current, _target), do: "btn btn-xs btn-ghost"

    defp message_class(%{source: "ui"}),
      do: "rounded-lg border border-primary/20 bg-primary/5 p-3"

    defp message_class(%{source: "system"}), do: "rounded-lg bg-base-200 p-3"
    defp message_class(_message), do: "rounded-lg border border-base-300 bg-base-100 p-3"

    defp format_time(%DateTime{} = time) do
      Calendar.strftime(time, "%H:%M:%S UTC")
    end

    defp format_time(_time), do: ""
  end
end
