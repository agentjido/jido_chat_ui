defmodule JidoChatUIWeb.Router do
  use JidoChatUIWeb, :router

  import JidoChatUIWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JidoChatUIWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JidoChatUIWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :current_scope,
      on_mount: [{JidoChatUIWeb.UserAuth, :mount_current_scope}] do
      live "/guides", GuideLive, :index
      live "/guides/getting-started", GuideLive, :getting_started
      live "/guides/onboarding-scope", GuideLive, :onboarding_scope
      live "/guides/configuration", GuideLive, :configuration
      live "/guides/rooms", GuideLive, :rooms
      live "/guides/bridges", GuideLive, :bridges
      live "/guides/agents", GuideLive, :agents
      live "/guides/jido-messaging", GuideLive, :jido_messaging
      live "/guides/building-a-new-adapter", GuideLive, :new_adapter
      live "/guides/adapters", GuideLive, :adapters
      live "/guides/adapters/:id", GuideLive, :adapter
      live "/guides/signal", GuideLive, :signal
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", JidoChatUIWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:jido_chat_ui, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JidoChatUIWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", JidoChatUIWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", JidoChatUIWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{JidoChatUIWeb.UserAuth, :require_authenticated_user}] do
      live "/rooms", RoomLive.Index, :index
      live "/rooms/new", RoomLive.Form, :new
      live "/rooms/:id", RoomLive.Show, :show
      live "/rooms/:id/edit", RoomLive.Form, :edit
      live "/rooms/:room_id/bridges", RoomBridgeLive.Index, :index

      live "/bridges", BridgeLive.Index, :index
      live "/bridges/new", BridgeLive.Form, :new
      live "/bridges/:id", BridgeLive.Show, :show
      live "/bridges/:id/edit", BridgeLive.Form, :edit

      live "/agents", AgentLive.Index, :index
      live "/agents/:id", AgentLive.Show, :show
      live "/ops", OpsLive.Index, :index
      live "/ops/signals", OpsLive.Index, :signals
      live "/ops/deliveries", OpsLive.Index, :deliveries
      live "/ops/dead-letters", OpsLive.Index, :dead_letters
    end

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", JidoChatUIWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
