defmodule JidoChatUIWeb.RoomLive.Show do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Chat
  alias JidoChatUI.Agents
  alias JidoChatUI.Messaging
  alias JidoChatUI.Messaging.Participants
  alias JidoChatUI.Messaging.Sync
  alias JidoChatUI.RoomTimeline

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_room_id={@room.id}>
      <.header>
        {@room.name}
        <:subtitle>{@room.description || "Internal shared room for adapter testing."}</:subtitle>
        <:actions>
          <.button navigate={~p"/rooms"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button navigate={~p"/rooms/#{@room}/bridges"}>
            <.icon name="hero-link" /> Bridges
          </.button>
          <.button variant="primary" navigate={~p"/rooms/#{@room}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit room
          </.button>
        </:actions>
      </.header>

      <div class="grid min-w-0 gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="min-w-0 max-w-full overflow-hidden rounded-lg border border-base-300 bg-base-100">
          {live_render(@socket, JidoChatUIWeb.RoomTimelineLive,
            id: "room-timeline-#{@room.id}",
            session: %{
              "room_id" => @room.id,
              "room_name" => @room.name,
              "current_user_email" => @current_scope.user.email
            }
          )}

          <div class="border-t border-base-300 bg-base-100 p-3">
            <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
              <div class="flex min-w-0 items-center gap-2 text-sm">
                <span class={[
                  "status",
                  @agent.running? && "status-success",
                  !@agent.running? && "status-warning"
                ]} />
                <span class="truncate font-medium">Room Assistant</span>
                <span class="badge badge-sm">{@agent_settings["agent_mode"]}</span>
                <span class="badge badge-sm">{if @agent.running?, do: "running", else: "idle"}</span>
                <span
                  :if={@agent_settings["relay_agent_replies"]}
                  class="badge badge-sm badge-warning"
                >
                  relay on
                </span>
                <span
                  :if={@agent_settings["auto_reply_adapter_messages"]}
                  class="badge badge-sm badge-info"
                >
                  auto on
                </span>
              </div>
              <div class="flex flex-wrap justify-end gap-1">
                <button
                  type="button"
                  class="btn btn-xs btn-ghost"
                  phx-click="assistant_reply"
                  phx-value-intent="summary"
                >
                  Summarize
                </button>
                <button
                  type="button"
                  class="btn btn-xs btn-ghost"
                  phx-click="assistant_reply"
                  phx-value-intent="debug"
                >
                  Debug
                </button>
                <button
                  type="button"
                  class="btn btn-xs btn-ghost"
                  phx-click="assistant_reply"
                  phx-value-intent="next_test"
                >
                  Next test
                </button>
              </div>
            </div>

            <form id="timeline-composer-form" phx-submit="timeline_message">
              <label class="sr-only" for={"timeline-composer-#{@composer_version}"}>Message</label>
              <div class="flex items-end gap-2 rounded-lg border border-base-300 bg-base-200/40 p-2 focus-within:border-base-content">
                <textarea
                  id={"timeline-composer-#{@composer_version}"}
                  name="body"
                  rows="1"
                  phx-hook="ChatComposer"
                  class="min-h-10 max-h-44 flex-1 resize-none border-0 bg-transparent px-2 py-2 text-sm leading-5 outline-none"
                  placeholder="Send a room message"
                ></textarea>
                <.button
                  class="btn btn-primary btn-square shrink-0"
                  phx-disable-with="..."
                  aria-label="Send"
                  title="Send"
                >
                  <.icon name="hero-paper-airplane" class="size-5" />
                </.button>
              </div>
            </form>
          </div>
        </section>

        <aside class="space-y-4">
          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="font-semibold">Message inspector</h2>
                <p class="mt-1 text-xs opacity-60">
                  Raw payload, normalized shape, persistence, and delivery metadata.
                </p>
              </div>
              <span class="badge badge-sm">{length(@messages)}</span>
            </div>

            <div
              :if={@messages == []}
              class="mt-3 rounded border border-dashed border-base-300 p-3 text-sm opacity-70"
            >
              No persisted room messages yet.
            </div>

            <div :if={@messages != []} class="mt-3 space-y-3">
              <.form for={%{}} as={:inspector} phx-change="select_message">
                <label
                  class="text-xs font-semibold uppercase opacity-60"
                  for="message-inspector-select"
                >
                  Message
                </label>
                <select
                  id="message-inspector-select"
                  name="inspector[message_id]"
                  class="select select-sm mt-1 w-full"
                >
                  <option
                    :for={message <- @messages}
                    value={message.id}
                    selected={@selected_message && @selected_message.id == message.id}
                  >
                    {message_label(message)}
                  </option>
                </select>
              </.form>

              <div :if={@selected_message} class="space-y-3">
                <.inspector_block
                  title="Provider payload"
                  value={provider_payload(@selected_message)}
                />
                <.inspector_block
                  title="Normalized message"
                  value={normalized_message(@selected_message)}
                />
                <.inspector_block
                  title="Persisted record"
                  value={persisted_record(@selected_message)}
                />
                <.inspector_block title="Delivery" value={delivery_record(@selected_message)} />
              </div>
            </div>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="font-semibold">Room settings</h2>
            <.list>
              <:item title="Status">{@room.status}</:item>
              <:item title="Metadata">{inspect(@room.metadata || %{})}</:item>
            </.list>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="font-semibold">Participants</h2>
                <p class="mt-1 text-xs opacity-60">Local users, adapter identities, and agents.</p>
              </div>
              <span class="badge badge-sm">{length(@participants)}</span>
            </div>

            <ul class="mt-3 space-y-2">
              <li
                :for={participant <- @participants}
                class="flex items-center justify-between gap-3 rounded bg-base-200 px-3 py-2"
              >
                <div class="min-w-0">
                  <p class="truncate text-sm font-medium">
                    {Participants.participant_name(participant)}
                  </p>
                  <p class="truncate text-xs opacity-60">
                    {participant.id} · {Participants.participant_source(participant)}
                  </p>
                </div>
                <div class="flex shrink-0 items-center gap-2">
                  <span class="badge badge-sm">{participant.type}</span>
                  <span class={presence_badge_class(participant.presence)}>
                    {participant.presence}
                  </span>
                </div>
              </li>
            </ul>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="font-semibold">Room Assistant</h2>
                <p class="mt-1 text-sm opacity-70">
                  Started automatically and registered with this room.
                </p>
              </div>
              <span class={[
                "badge",
                @agent.running? && "badge-success",
                !@agent.running? && "badge-warning"
              ]}>
                {if @agent.running?, do: "running", else: "idle"}
              </span>
            </div>
            <div class="mt-4 space-y-3 border-t border-base-300 pt-4">
              <div>
                <p class="text-xs font-semibold uppercase opacity-60">Agent mode</p>
                <div class="join mt-2">
                  <button
                    type="button"
                    class={agent_mode_button_class(@agent_settings, "deterministic")}
                    phx-click="set_agent_mode"
                    phx-value-mode="deterministic"
                  >
                    Rules
                  </button>
                  <button
                    type="button"
                    class={agent_mode_button_class(@agent_settings, "llm")}
                    phx-click="set_agent_mode"
                    phx-value-mode="llm"
                  >
                    LLM
                  </button>
                </div>
              </div>

              <div class="rounded bg-base-200/60 p-3">
                <div class="flex items-center justify-between gap-3">
                  <div class="min-w-0">
                    <p class="text-sm font-medium">Relay replies</p>
                    <p class="mt-1 text-xs opacity-60">
                      {if @agent_settings["relay_agent_replies"],
                        do: "Agent replies route through active bridges.",
                        else: "Agent replies stay local to this room."}
                    </p>
                  </div>
                  <button
                    type="button"
                    class={[
                      "btn btn-xs shrink-0",
                      @agent_settings["relay_agent_replies"] && "btn-warning",
                      !@agent_settings["relay_agent_replies"] && "btn-ghost"
                    ]}
                    phx-click="toggle_agent_relay"
                    phx-value-enabled={to_string(!@agent_settings["relay_agent_replies"])}
                  >
                    {if @agent_settings["relay_agent_replies"], do: "Disable", else: "Enable"}
                  </button>
                </div>
              </div>

              <div class="rounded bg-base-200/60 p-3">
                <div class="flex items-center justify-between gap-3">
                  <div class="min-w-0">
                    <p class="text-sm font-medium">Auto-reply to adapters</p>
                    <p class="mt-1 text-xs opacity-60">
                      {if @agent_settings["auto_reply_adapter_messages"],
                        do: "Adapter messages can trigger the assistant automatically.",
                        else: "Only explicit assistant mentions trigger automatic replies."}
                    </p>
                  </div>
                  <button
                    type="button"
                    class={[
                      "btn btn-xs shrink-0",
                      @agent_settings["auto_reply_adapter_messages"] && "btn-warning",
                      !@agent_settings["auto_reply_adapter_messages"] && "btn-ghost"
                    ]}
                    phx-click="toggle_agent_auto_reply"
                    phx-value-enabled={to_string(!@agent_settings["auto_reply_adapter_messages"])}
                  >
                    {if @agent_settings["auto_reply_adapter_messages"], do: "Disable", else: "Enable"}
                  </button>
                </div>
              </div>
            </div>
            <.link navigate={~p"/agents/room_assistant"} class="btn btn-sm mt-3">Open agent</.link>
          </section>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Chat.subscribe_rooms(socket.assigns.current_scope)
      subscribe_to_messaging_signals()
    end

    room = Chat.get_room!(socket.assigns.current_scope, id)
    Sync.log_sync_result("room mount", Sync.sync_room_topology(room))
    _ = Participants.ensure_room_defaults(room, socket.assigns.current_scope.user)

    {:ok,
     socket
     |> assign(:page_title, "Show Room")
     |> assign(:composer_version, 0)
     |> assign(:room, room)
     |> assign(:agent, Agents.get_agent("room_assistant"))
     |> assign(:agent_settings, Agents.room_settings(room))
     |> assign(:participants, Participants.list_for_room(room, socket.assigns.current_scope.user))
     |> assign(:selected_message_id, nil)
     |> assign_message_inspector()}
  end

  @impl true
  def handle_event("timeline_message", %{"body" => body}, socket) do
    body = String.trim(to_string(body))

    socket =
      if body != "" do
        user = socket.assigns.current_scope.user
        {:ok, participant} = Participants.ensure_user_participant(user)
        author = Participants.participant_name(participant)
        room = socket.assigns.room

        {:ok, message} =
          Messaging.save_message(%{
            room_id: to_string(room.id),
            sender_id: participant.id,
            role: :user,
            content: [%{type: :text, text: body}],
            status: :sent,
            metadata: %{
              "author" => author,
              "participant_id" => participant.id,
              "source" => "ui"
            }
          })

        _ = Participants.add_message_to_room_server(room, message)
        delivery_result = route_room_message(room.id, body)
        message = persist_delivery_result(message, delivery_result)

        room.id
        |> RoomTimeline.ensure_started(room.name)
        |> RoomTimeline.post_message(
          message
          |> RoomTimeline.from_messaging_message()
          |> put_delivery_status(delivery_result)
        )

        assign(socket, :selected_message_id, message.id)
      else
        socket
      end

    {:noreply,
     socket
     |> update(:composer_version, &(&1 + 1))
     |> refresh_room_participants()
     |> assign_message_inspector()}
  end

  def handle_event("select_message", %{"inspector" => %{"message_id" => message_id}}, socket) do
    {:noreply,
     socket
     |> assign(:selected_message_id, message_id)
     |> assign_message_inspector()}
  end

  def handle_event("assistant_reply", params, socket) do
    socket =
      socket.assigns.room
      |> save_assistant_reply(socket.assigns.current_scope, params["intent"])
      |> case do
        {:ok, {message, delivery_result}} ->
          socket.assigns.room.id
          |> RoomTimeline.ensure_started(socket.assigns.room.name)
          |> RoomTimeline.post_message(
            message
            |> RoomTimeline.from_messaging_message()
            |> put_delivery_status(delivery_result)
          )

          socket
          |> refresh_room_participants()
          |> assign(:selected_message_id, message.id)
          |> assign_message_inspector()

        {:error, reason} ->
          put_flash(socket, :error, "Room Assistant failed: #{inspect(reason)}")
      end

    {:noreply, socket}
  end

  def handle_event("set_agent_mode", %{"mode" => mode}, socket) do
    metadata = Agents.put_room_settings(socket.assigns.room.metadata || %{}, %{agent_mode: mode})

    {:noreply, update_room_settings(socket, metadata, "Room Assistant mode updated.")}
  end

  def handle_event("toggle_agent_relay", %{"enabled" => enabled}, socket) do
    metadata =
      Agents.put_room_settings(socket.assigns.room.metadata || %{}, %{
        relay_agent_replies: enabled
      })

    {:noreply, update_room_settings(socket, metadata, "Room Assistant relay setting updated.")}
  end

  def handle_event("toggle_agent_auto_reply", %{"enabled" => enabled}, socket) do
    metadata =
      Agents.put_room_settings(socket.assigns.room.metadata || %{}, %{
        auto_reply_adapter_messages: enabled
      })

    {:noreply,
     update_room_settings(socket, metadata, "Room Assistant auto-reply setting updated.")}
  end

  defp save_assistant_reply(room, current_scope, intent) do
    agent_settings = Agents.room_settings(room)

    with {:ok, _agent_pid} <- Agents.ensure_started("room_assistant"),
         {:ok, assistant} <- Participants.ensure_room_assistant_participant(),
         {:ok, messages} <- Messaging.list_messages(to_string(room.id), limit: 20),
         {:ok, reply} <-
           Agents.compose_room_reply(%{
             room: room,
             participants: Participants.list_for_room(room, current_scope.user),
             bridges: Chat.list_room_bridges_for_room(current_scope, room.id),
             messages: messages,
             intent: intent,
             mode: agent_settings["agent_mode"]
           }),
         {:ok, message} <-
           Messaging.save_message(%{
             room_id: to_string(room.id),
             sender_id: assistant.id,
             role: :assistant,
             content: [%{type: :text, text: reply.body}],
             status: :sent,
             metadata: %{
               "author" => Participants.participant_name(assistant),
               "participant_id" => assistant.id,
               "source" => "agent",
               "agent_mode" => to_string(reply.mode),
               "intent" => reply.intent,
               "relay_agent_replies" => agent_settings["relay_agent_replies"]
             }
           }) do
      _ = Participants.add_message_to_room_server(room, message)

      delivery_result =
        relay_agent_reply(room.id, reply.body, agent_settings["relay_agent_replies"])

      message = persist_delivery_result(message, delivery_result)

      {:ok, {message, delivery_result}}
    end
  end

  defp update_room_settings(socket, metadata, flash) do
    case Chat.update_room(socket.assigns.current_scope, socket.assigns.room, %{metadata: metadata}) do
      {:ok, room} ->
        socket
        |> assign(:room, room)
        |> assign(:agent_settings, Agents.room_settings(room))
        |> put_flash(:info, flash)

      {:error, reason} ->
        put_flash(socket, :error, "Room Assistant settings failed: #{inspect(reason)}")
    end
  end

  defp relay_agent_reply(_room_id, _body, false), do: :agent_local_only
  defp relay_agent_reply(room_id, body, true), do: route_room_message(room_id, body)

  defp route_room_message(room_id, body) do
    ensure_adapter_modules_loaded()

    case Messaging.resolve_outbound_routes(to_string(room_id)) do
      {:ok, []} ->
        :no_routes

      {:ok, _routes} ->
        Messaging.route_outbound(to_string(room_id), body)

      {:error, _reason} = error ->
        error
    end
  end

  defp ensure_adapter_modules_loaded do
    JidoChatUI.Adapters.all()
    :ok
  end

  defp persist_delivery_result(message, delivery_result) do
    message = annotate_delivery_result(message, delivery_result)

    case Messaging.save_message_struct(message) do
      {:ok, saved_message} -> saved_message
      {:error, _reason} -> message
    end
  end

  defp annotate_delivery_result(message, delivery_result) do
    metadata =
      (message.metadata || %{})
      |> Map.merge(delivery_metadata(delivery_result))

    %{
      message
      | status: delivery_message_status(message.status, delivery_result),
        metadata: metadata,
        updated_at: DateTime.utc_now(:second)
    }
  end

  defp delivery_message_status(_status, {:ok, summary}) do
    delivered = summary_items(summary, :delivered)
    failed = summary_items(summary, :failed)

    cond do
      delivered != [] and failed == [] -> :delivered
      delivered != [] -> :sent
      true -> :failed
    end
  end

  defp delivery_message_status(_status, {:error, _reason}), do: :failed
  defp delivery_message_status(status, :no_routes), do: status
  defp delivery_message_status(status, :agent_local_only), do: status

  defp delivery_metadata({:ok, summary}) do
    summary_metadata(summary, "delivered")
  end

  defp delivery_metadata({:error, {:delivery_failed, summary}}) do
    summary
    |> summary_metadata("delivery_failed")
    |> Map.put("delivery_error", inspect(:delivery_failed))
  end

  defp delivery_metadata({:error, reason}) do
    %{
      "route_decision" => "delivery_error",
      "delivery_error" => inspect(reason),
      "attempted" => 0,
      "delivered" => 0,
      "failed" => 1
    }
  end

  defp delivery_metadata(:no_routes) do
    %{
      "route_decision" => "no_routes",
      "attempted" => 0,
      "delivered" => 0,
      "failed" => 0
    }
  end

  defp delivery_metadata(:agent_local_only) do
    %{
      "route_decision" => "agent_local_only",
      "attempted" => 0,
      "delivered" => 0,
      "failed" => 0
    }
  end

  defp summary_metadata(summary, route_decision) do
    delivered = summary_items(summary, :delivered)
    failed = summary_items(summary, :failed)

    %{
      "route_decision" => route_decision,
      "attempted" => metadata_value(summary, :attempted) || length(delivered) + length(failed),
      "delivered" => length(delivered),
      "failed" => length(failed),
      "delivered_routes" => Enum.map(delivered, &delivery_success_record/1),
      "failed_routes" => Enum.map(failed, &delivery_failure_record/1)
    }
    |> Map.merge(first_route_metadata(delivered, failed))
  end

  defp summary_items(summary, key) do
    case metadata_value(summary, key) do
      items when is_list(items) -> items
      _other -> []
    end
  end

  defp first_route_metadata(delivered, failed) do
    (List.first(delivered) || List.first(failed))
    |> case do
      nil ->
        %{}

      delivery ->
        delivery
        |> metadata_value(:route)
        |> route_metadata()
    end
  end

  defp delivery_success_record(success) do
    route = metadata_value(success, :route) || %{}
    result = metadata_value(success, :result) || %{}

    %{
      "bridge_id" => route_value(route, :bridge_id),
      "channel" => route_value(route, :channel),
      "external_room_id" => route_value(route, :external_room_id),
      "message_id" => normalize_delivery_value(metadata_value(result, :message_id)),
      "operation" => normalize_delivery_value(metadata_value(result, :operation))
    }
    |> compact_metadata()
  end

  defp delivery_failure_record(failure) do
    route = metadata_value(failure, :route) || %{}

    %{
      "bridge_id" => route_value(route, :bridge_id),
      "channel" => route_value(route, :channel),
      "external_room_id" => route_value(route, :external_room_id),
      "reason" => inspect(metadata_value(failure, :reason))
    }
    |> compact_metadata()
  end

  defp route_metadata(route) do
    %{
      "bridge_id" => route_value(route, :bridge_id),
      "channel" => route_value(route, :channel),
      "delivery_external_room_id" => route_value(route, :external_room_id)
    }
    |> compact_metadata()
  end

  defp route_value(route, key), do: route |> metadata_value(key) |> normalize_delivery_value()

  defp normalize_delivery_value(nil), do: nil
  defp normalize_delivery_value(value) when is_binary(value), do: value
  defp normalize_delivery_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_delivery_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_delivery_value(value), do: inspect(value)

  defp compact_metadata(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp put_delivery_status(message, {:ok, %{delivered: delivered, failed: failed}})
       when failed != [] do
    %{message | status: "partial:#{length(delivered)}/#{length(delivered) + length(failed)}"}
  end

  defp put_delivery_status(message, {:ok, %{delivered: delivered}}) do
    %{message | status: "delivered:#{length(delivered)}"}
  end

  defp put_delivery_status(message, :no_routes), do: %{message | status: "no_routes"}
  defp put_delivery_status(message, :agent_local_only), do: %{message | status: "local_only"}

  defp put_delivery_status(message, {:error, reason}) do
    metadata = Map.put(message.metadata || %{}, "delivery_error", inspect(reason))
    %{message | status: "delivery_failed", metadata: metadata}
  end

  @impl true
  def handle_info(
        {:updated, %JidoChatUI.Chat.Room{id: id} = room},
        %{assigns: %{room: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:room, room)
     |> refresh_room_participants()}
  end

  def handle_info(
        {:deleted, %JidoChatUI.Chat.Room{id: id}},
        %{assigns: %{room: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current room was deleted.")
     |> push_navigate(to: ~p"/rooms")}
  end

  def handle_info({type, %JidoChatUI.Chat.Room{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({:signal, %{type: "jido.messaging.room.message_added", data: data}}, socket) do
    if same_room?(data_value(data, :room_id), socket.assigns.room.id) do
      {:noreply,
       socket
       |> refresh_room_participants()
       |> assign_message_inspector()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:signal, %{type: "jido.messaging.room.participant_joined", data: data}},
        socket
      ) do
    if same_room?(data_value(data, :room_id), socket.assigns.room.id) do
      {:noreply, refresh_room_participants(socket)}
    else
      {:noreply, socket}
    end
  end

  defp subscribe_to_messaging_signals do
    bus_name = Module.concat(Messaging, SignalBus)
    _ = Jido.Signal.Bus.subscribe(bus_name, "jido.messaging.room.message_added")
    _ = Jido.Signal.Bus.subscribe(bus_name, "jido.messaging.room.participant_joined")
    :ok
  rescue
    _exception -> :ok
  catch
    :exit, _reason -> :ok
  end

  defp refresh_room_participants(socket) do
    socket
    |> assign(:agent, Agents.get_agent("room_assistant"))
    |> assign(:agent_settings, Agents.room_settings(socket.assigns.room))
    |> assign(
      :participants,
      Participants.list_for_room(socket.assigns.room, socket.assigns.current_scope.user)
    )
  end

  defp assign_message_inspector(socket) do
    messages =
      case Messaging.list_messages(to_string(socket.assigns.room.id), limit: 100) do
        {:ok, messages} -> messages
        {:error, _reason} -> []
      end

    selected_message =
      Enum.find(messages, &(&1.id == socket.assigns[:selected_message_id])) || List.last(messages)

    socket
    |> assign(:messages, messages)
    |> assign(:selected_message, selected_message)
    |> assign(:selected_message_id, selected_message && selected_message.id)
  end

  attr :title, :string, required: true
  attr :value, :any, required: true

  defp inspector_block(assigns) do
    ~H"""
    <div>
      <p class="text-xs font-semibold uppercase opacity-60">{@title}</p>
      <pre class="mt-1 max-h-48 overflow-auto rounded bg-base-200 p-3 text-[0.7rem] leading-relaxed"><%= inspect(@value, pretty: true, limit: 40, printable_limit: 1_500) %></pre>
    </div>
    """
  end

  defp message_label(message) do
    source =
      message.metadata
      |> metadata_value(:source)
      |> case do
        nil -> metadata_value(message.metadata, :channel) || "message"
        value -> value
      end

    "#{source}: #{String.slice(message_text(message), 0, 48)}"
  end

  defp provider_payload(message) do
    metadata = message.metadata || %{}

    metadata_value(metadata, :raw_payload) ||
      metadata_value(metadata, :provider_payload) ||
      metadata_value(metadata, :raw) ||
      metadata_value(metadata, :payload) ||
      metadata_value(metadata, :event) ||
      %{"metadata" => metadata}
  end

  defp normalized_message(message) do
    %{
      id: message.id,
      room_id: message.room_id,
      sender_id: message.sender_id,
      role: message.role,
      source:
        metadata_value(message.metadata, :source) || metadata_value(message.metadata, :channel),
      text: message_text(message)
    }
  end

  defp persisted_record(message) do
    %{
      id: message.id,
      room_id: message.room_id,
      thread_id: message.thread_id,
      external_id: message.external_id,
      status: message.status,
      inserted_at: message.inserted_at
    }
  end

  defp delivery_record(message) do
    metadata = message.metadata || %{}

    %{
      status: message.status,
      bridge_id: metadata_value(metadata, :bridge_id),
      channel: metadata_value(metadata, :channel),
      delivery_error: metadata_value(metadata, :delivery_error),
      route_decision: metadata_value(metadata, :route_decision),
      delivered: metadata_value(metadata, :delivered)
    }
  end

  defp message_text(message) do
    Enum.find_value(message.content || [], "", fn
      %{type: :text, text: text} when is_binary(text) -> text
      %{"type" => "text", "text" => text} when is_binary(text) -> text
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      text when is_binary(text) -> text
      _content -> nil
    end)
  end

  defp agent_mode_button_class(settings, mode) do
    [
      "btn join-item btn-xs",
      settings["agent_mode"] == mode && "btn-primary",
      settings["agent_mode"] != mode && "btn-ghost"
    ]
  end

  defp presence_badge_class(:online), do: "badge badge-sm badge-success"
  defp presence_badge_class(:away), do: "badge badge-sm badge-warning"
  defp presence_badge_class(:busy), do: "badge badge-sm badge-error"
  defp presence_badge_class(_presence), do: "badge badge-sm"

  defp data_value(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, Atom.to_string(key))
  end

  defp data_value(_data, _key), do: nil

  defp metadata_value(metadata, key) when is_map(metadata),
    do: Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))

  defp metadata_value(_metadata, _key), do: nil
  defp same_room?(left, right), do: to_string(left) == to_string(right)
end
