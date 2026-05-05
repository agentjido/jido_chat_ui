defmodule JidoChatUIWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use JidoChatUIWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_room_id, :any, default: nil, doc: "the active room id for sidebar highlighting"

  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:adapter_statuses, JidoChatUI.Adapters.health_statuses())
      |> assign(:sidebar_rooms, sidebar_rooms(assigns.current_scope))

    ~H"""
    <header class="border-b border-base-300 px-3 py-2 sm:px-6 lg:px-8">
      <div class="flex flex-wrap items-center gap-2">
        <div class="min-w-0 flex-1 basis-full sm:basis-auto">
          <.link
            navigate={~p"/rooms"}
            class="flex w-fit max-w-full items-center gap-2 text-sm font-semibold"
          >
            <span class="grid size-8 place-items-center rounded bg-base-300">JC</span>
            <span class="truncate">Jido Chat UI</span>
          </.link>
        </div>
        <div class="min-w-0 flex-none">
          <ul class="flex flex-wrap items-center justify-start gap-1 sm:justify-end">
            <li><.link navigate={~p"/bridges"} class="btn btn-ghost btn-sm">Bridges</.link></li>
            <li><.link navigate={~p"/agents"} class="btn btn-ghost btn-sm">Agents</.link></li>
            <li><.link navigate={~p"/ops"} class="btn btn-ghost btn-sm">Ops</.link></li>
            <li><.link navigate={~p"/guides"} class="btn btn-ghost btn-sm">Guides</.link></li>
            <li>
              <.adapter_status_bar statuses={@adapter_statuses} />
            </li>
            <li><.theme_toggle /></li>
          </ul>
        </div>
      </div>
    </header>

    <div class="grid min-h-[calc(100vh-4rem)] grid-cols-[7.25rem_minmax(0,1fr)] md:grid-cols-[9rem_minmax(0,1fr)] max-[520px]:grid-cols-1">
      <aside
        :if={@current_scope}
        class="border-r border-base-300 bg-base-200/40 max-[520px]:border-b max-[520px]:border-r-0"
      >
        <div class="sticky top-0 max-h-[calc(100vh-4rem)] space-y-5 overflow-y-auto px-2 py-4 md:px-3 max-[520px]:static max-[520px]:max-h-none">
          <nav aria-label="Rooms" class="space-y-2">
            <div class="flex items-center justify-between gap-3">
              <.link
                navigate={~p"/rooms"}
                class="text-xs font-semibold uppercase tracking-wide opacity-60"
              >
                Rooms
              </.link>
              <.link navigate={~p"/rooms/new"} class="btn btn-ghost btn-xs" title="New room">
                <.icon name="hero-plus" class="size-4" />
              </.link>
            </div>

            <div class="space-y-1">
              <.link
                :for={room <- @sidebar_rooms}
                navigate={~p"/rooms/#{room}"}
                class={room_nav_class(room, @current_room_id)}
              >
                <span class="opacity-60">#</span>
                <span class="truncate">{room.name}</span>
                <span
                  :if={room.status != "active"}
                  class="ml-auto text-[0.65rem] uppercase opacity-50"
                >
                  {room.status}
                </span>
              </.link>
            </div>
          </nav>

          <nav aria-label="Setup" class="space-y-1 border-t border-base-300 pt-4">
            <.link
              navigate={~p"/guides/getting-started"}
              class="flex items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-base-200"
            >
              <.icon name="hero-map" class="size-4 opacity-60" /> Start
            </.link>
            <.link
              navigate={~p"/guides/adapters"}
              class="flex items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-base-200"
            >
              <.icon name="hero-puzzle-piece" class="size-4 opacity-60" /> Adapters
            </.link>
            <.link
              navigate={~p"/guides/bridges"}
              class="flex items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-base-200"
            >
              <.icon name="hero-link" class="size-4 opacity-60" /> Bridge Setup
            </.link>
          </nav>
        </div>
      </aside>

      <main class="min-w-0 px-2 py-5 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-7xl min-w-0 space-y-6">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :statuses, :list, required: true

  def adapter_status_bar(assigns) do
    ~H"""
    <div
      class="flex max-w-[9rem] flex-wrap items-center justify-end gap-x-1 gap-y-0.5 overflow-hidden rounded border border-base-300 bg-base-200/70 px-2 py-1 sm:max-w-none xl:flex-nowrap"
      aria-label="Adapter connection status"
    >
      <.adapter_status_pill :for={status <- @statuses} status={status} />
    </div>
    """
  end

  attr :status, :map, required: true

  def adapter_status_pill(assigns) do
    ~H"""
    <span
      class="flex shrink-0 items-center gap-1 rounded px-1 py-0.5 text-[0.625rem] font-semibold uppercase leading-none"
      title={@status.title}
      aria-label={@status.title}
    >
      <span class={["adapter-pulse", adapter_pulse_class(@status.status)]} />
      <span>{@status.short_name}</span>
    </span>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  defp adapter_pulse_class(:connected), do: "adapter-pulse-connected"
  defp adapter_pulse_class(:needs_config), do: "adapter-pulse-needs-config"
  defp adapter_pulse_class(:unavailable), do: "adapter-pulse-unavailable"

  defp sidebar_rooms(nil), do: []

  defp sidebar_rooms(current_scope) do
    JidoChatUI.Chat.list_rooms(current_scope)
  rescue
    _exception -> []
  catch
    :exit, _reason -> []
  end

  defp room_nav_class(room, current_room_id) do
    active? = to_string(room.id) == to_string(current_room_id)

    [
      "flex items-center gap-2 rounded px-2 py-1.5 text-sm",
      active? && "bg-primary text-primary-content font-medium",
      !active? && "hover:bg-base-200"
    ]
  end
end
