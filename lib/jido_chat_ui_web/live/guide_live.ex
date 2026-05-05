defmodule JidoChatUIWeb.GuideLive do
  use JidoChatUIWeb, :live_view

  alias JidoChatUI.Adapters
  alias JidoChatUI.Docs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>{@page_summary}</:subtitle>
      </.header>

      <section :if={@mode == :index} class="space-y-8">
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <.guide_card :for={guide <- @workflow_guides} guide={guide} />
        </div>

        <div class="space-y-3">
          <div class="flex items-center justify-between gap-4">
            <div>
              <h2 class="text-base font-semibold">Adapter Setup</h2>
              <p class="text-sm opacity-70">
                Start with one adapter, get text working, then widen into replies, media, and agents.
              </p>
            </div>
            <.link navigate={~p"/guides/adapters"} class="btn btn-sm btn-outline">
              View all
            </.link>
          </div>
          <.adapter_status_grid statuses={@adapter_statuses} />
        </div>
      </section>

      <section :if={@mode == :adapters} class="space-y-5">
        <.adapter_status_grid statuses={@adapter_statuses} />
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <.adapter_guide_card
            :for={guide <- @adapter_guides}
            guide={guide}
            statuses={@adapter_statuses}
          />
        </div>
      </section>

      <section :if={@mode == :doc} class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <article class="jido-docs rounded-lg border border-base-300 bg-base-100 p-6">
          {Phoenix.HTML.raw(@doc_html)}
        </article>

        <aside class="space-y-4">
          <section :if={@adapter_status} class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="text-sm font-semibold">Adapter Status</h2>
            <div class="mt-3 flex items-center justify-between gap-3">
              <span class="font-medium">{@adapter_status.name}</span>
              <span class={["badge", status_badge_class(@adapter_status.status)]}>
                {status_text(@adapter_status.status)}
              </span>
            </div>
            <p class="mt-2 text-sm opacity-70">{@adapter_status.title}</p>
            <ul :if={@adapter_status.missing_env != []} class="mt-3 space-y-1 text-xs">
              <li :for={key <- @adapter_status.missing_env} class="font-mono">{key}</li>
            </ul>
          </section>

          <section class="rounded-lg border border-base-300 bg-base-100 p-4">
            <h2 class="text-sm font-semibold">Next Actions</h2>
            <div class="mt-3 space-y-2">
              <.action_link :for={action <- @next_actions} action={action} />
            </div>
          </section>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    page = resolve_page(socket.assigns.live_action || :index, params)

    {:ok,
     socket
     |> assign(:page_title, page.title)
     |> assign(:page_summary, page.summary)
     |> assign(:mode, page.mode)
     |> assign(:doc, page[:doc])
     |> assign(:doc_html, rendered_doc(page))
     |> assign(:workflow_guides, Docs.workflow_guides())
     |> assign(:adapter_guides, Docs.adapter_guides())
     |> assign(:adapter_statuses, Adapters.health_statuses())
     |> assign(:adapter_status, adapter_status(page))
     |> assign(:next_actions, next_actions(page))}
  end

  attr :guide, :map, required: true

  def guide_card(assigns) do
    ~H"""
    <.link
      navigate={@guide.route}
      class="block rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
    >
      <p class="font-medium">{@guide.title}</p>
      <p class="mt-1 text-sm opacity-70">{@guide.summary}</p>
    </.link>
    """
  end

  attr :statuses, :list, required: true

  def adapter_status_grid(assigns) do
    ~H"""
    <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      <.link
        :for={status <- @statuses}
        navigate={adapter_guide_path(status.id)}
        class="rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
      >
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="font-medium">{status.name}</p>
            <p class="mt-1 text-xs uppercase tracking-wide opacity-60">{status.short_name}</p>
          </div>
          <span class={["badge", status_badge_class(status.status)]}>
            {status_text(status.status)}
          </span>
        </div>
        <p class="mt-3 text-sm opacity-70">{status.title}</p>
      </.link>
    </div>
    """
  end

  attr :guide, :map, required: true
  attr :statuses, :list, required: true

  def adapter_guide_card(assigns) do
    assigns =
      assign(assigns, :status, status_for(assigns.statuses, assigns.guide.adapter_id))

    ~H"""
    <.link
      navigate={@guide.route}
      class="block rounded-lg border border-base-300 bg-base-100 p-4 hover:bg-base-200"
    >
      <div class="flex items-center justify-between gap-3">
        <p class="font-medium">{@guide.title}</p>
        <span :if={@status} class={["badge", status_badge_class(@status.status)]}>
          {status_text(@status.status)}
        </span>
      </div>
      <p class="mt-2 text-sm opacity-70">{@guide.summary}</p>
    </.link>
    """
  end

  attr :action, :map, required: true

  def action_link(assigns) do
    ~H"""
    <.link
      navigate={@action.path}
      class="block rounded border border-base-300 bg-base-200/40 p-3 hover:bg-base-200"
    >
      <p class="text-sm font-medium">{@action.label}</p>
      <p class="mt-1 text-xs opacity-70">{@action.detail}</p>
    </.link>
    """
  end

  defp resolve_page(:index, _params) do
    %{
      mode: :index,
      title: "Guides",
      summary: "Interactive setup docs for rooms, bridges, adapters, messaging, and agents."
    }
  end

  defp resolve_page(:adapters, _params) do
    %{
      mode: :adapters,
      title: "Adapter Setup",
      summary: "Configure one provider at a time, then prove inbound and outbound chat."
    }
  end

  defp resolve_page(:adapter, %{"id" => id}) do
    doc = Docs.adapter_guide(id) || raise ArgumentError, "unknown adapter guide: #{id}"
    doc_page(doc)
  end

  defp resolve_page(:getting_started, _params), do: doc_page(Docs.get!("getting-started"))
  defp resolve_page(:onboarding_scope, _params), do: doc_page(Docs.get!("onboarding-scope"))
  defp resolve_page(:configuration, _params), do: doc_page(Docs.get!("configuration"))
  defp resolve_page(:rooms, _params), do: doc_page(Docs.get!("rooms"))
  defp resolve_page(:bridges, _params), do: doc_page(Docs.get!("bridges"))
  defp resolve_page(:agents, _params), do: doc_page(Docs.get!("jidoka-agents"))
  defp resolve_page(:jido_messaging, _params), do: doc_page(Docs.get!("jido-messaging-state"))
  defp resolve_page(:new_adapter, _params), do: doc_page(Docs.get!("building-a-new-adapter"))
  defp resolve_page(:signal, _params), do: doc_page(Docs.get!("signal"))

  defp doc_page(doc) do
    %{
      mode: :doc,
      title: doc.title,
      summary: doc.summary,
      doc: doc
    }
  end

  defp rendered_doc(%{mode: :doc, doc: doc}), do: Docs.to_html!(doc)
  defp rendered_doc(_page), do: nil

  defp adapter_status(%{doc: %{adapter_id: adapter_id}}) do
    Adapters.health_statuses()
    |> status_for(adapter_id)
  end

  defp adapter_status(_page), do: nil

  defp status_for(statuses, adapter_id) do
    Enum.find(statuses, &(&1.id == adapter_id))
  end

  defp next_actions(%{doc: %{category: :adapter, adapter_id: "signal"}}) do
    [
      %{
        label: "Read adapter setup",
        path: "/guides/adapters",
        detail: "Compare Signal with bundled adapters."
      },
      %{
        label: "Create a bridge",
        path: "/bridges/new",
        detail: "Available after opting into the Signal package."
      }
    ]
  end

  defp next_actions(%{doc: %{category: :adapter}}) do
    [
      %{
        label: "Review configuration",
        path: "/guides/configuration",
        detail: "Confirm env vars and safe test targets."
      },
      %{
        label: "Create a bridge",
        path: "/bridges/new",
        detail: "Store provider IDs and env-var names."
      },
      %{
        label: "Bind to a room",
        path: "/rooms",
        detail: "Attach the bridge to a shared room timeline."
      }
    ]
  end

  defp next_actions(%{doc: %{id: "getting-started"}}) do
    [
      %{
        label: "Check adapter setup",
        path: "/guides/adapters",
        detail: "Pick the first provider to test."
      },
      %{label: "Create a room", path: "/rooms/new", detail: "Start one focused smoke-test room."}
    ]
  end

  defp next_actions(%{doc: %{id: "onboarding-scope"}}) do
    [
      %{
        label: "Getting started",
        path: "/guides/getting-started",
        detail: "Walk through the current happy path."
      },
      %{
        label: "Adapter setup",
        path: "/guides/adapters",
        detail: "Compare provider setup pages against the scope."
      }
    ]
  end

  defp next_actions(%{doc: %{id: "configuration"}}) do
    [
      %{
        label: "Open adapter guides",
        path: "/guides/adapters",
        detail: "See required keys by provider."
      },
      %{
        label: "Create a bridge",
        path: "/bridges/new",
        detail: "Use env-var names, not raw secrets."
      }
    ]
  end

  defp next_actions(_page) do
    [
      %{
        label: "Getting started",
        path: "/guides/getting-started",
        detail: "Walk through room, bridge, and smoke test setup."
      },
      %{
        label: "Adapter setup",
        path: "/guides/adapters",
        detail: "Configure real chat providers."
      }
    ]
  end

  defp adapter_guide_path("signal"), do: "/guides/signal"
  defp adapter_guide_path(id), do: "/guides/adapters/#{id}"

  defp status_badge_class(:connected), do: "badge-success"
  defp status_badge_class(:needs_config), do: "badge-warning"
  defp status_badge_class(:unavailable), do: "badge-error"

  defp status_text(:connected), do: "ready"
  defp status_text(:needs_config), do: "needs config"
  defp status_text(:unavailable), do: "missing package"
end
