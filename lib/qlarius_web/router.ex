defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import QlariusWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :widgets do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :allow_iframe
  end

  # Based on https://elixirforum.com/t/how-to-embed-a-liveview-via-iframe/65066
  defp allow_iframe(conn, _opts) do
    conn
    # This header is set to SAMEORIGIN by put_secure_browser_headers, which
    # prevents embedding in an iframe.
    |> delete_resp_header("x-frame-options")
    # Not sure where it's set but the default CSP header appears to be
    # "base-uri 'self'; frame-ancestors 'self';" Override it here to remove
    # frame-ancestors as that also blocks iframes
    |> put_resp_header("content-security-policy", "base-url 'self'")
  end

  pipeline :marketer do
    # This is used to highlight which tab we're on at the top
    import QlariusWeb.Layouts, only: [set_current_path: 2]
    plug :set_current_path
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ------ MARKETER ROUTES ------

  scope "/", QlariusWeb do
    pipe_through [:browser, :marketer]

    resources "/targets", TargetController
    resources "/media_pieces", MediaPieceController
    resources "/media_sequences", MediaSequenceController, only: [:index, :new, :create]

    live_session :marketer, on_mount: [{QlariusWeb.Layouts, :set_current_path}] do
      live "/trait_groups", TraitGroupLive.Index, :index
      live "/trait_manager", TraitManagerLive.Index, :index

      live "/trait_categories", TraitCategoryLive.Index, :index
      live "/trait_categories/new", TraitCategoryLive.Index, :new
      live "/trait_categories/:id/edit", TraitCategoryLive.Index, :edit

      live "/survey_manager/new/:category_id", SurveyManagerLive, :new
      live "/survey_manager/edit/:id", SurveyManagerLive, :edit
      live "/survey_manager/:id", SurveyManagerLive, :show
      live "/survey_manager", SurveyManagerLive, :index
    end
  end

  # ------ /MARKETER ROUTES ------

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:qlarius, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QlariusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/widgets", QlariusWeb.Widgets do
    pipe_through [:widgets]

    get "/content/:id", ContentController, :show

    live_session :widgets, on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
      live "/arcade/group/:group_id", ArcadeLive
      live "/wallet", WalletLive
    end
  end

  scope "/", QlariusWeb do
    pipe_through [:browser]

    live_session :current_scope, on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
      get "/", PageController, :home
      live "/users/settings", UserSettingsLive, :edit
      live "/wallet", WalletLive, :index
      live "/ads", AdsLive, :index
      live "/me_file", MeFileLive, :index
      live "/proxy_users", ProxyUsersLive, :index
      get "/me_file/surveys", MeFileController, :surveys
      live "/me_file/surveys/:survey_id", MeFileSurveyLive, :show
      live "/me_file/surveys/:survey_id/:index", MeFileSurveyLive, :show
    end

    resources "/tiqits", TiqitController

    get "/jump/:id", AdController, :jump
  end

  scope "/creators", QlariusWeb.Creators do
    pipe_through [:browser]

    live_session :creators, on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
      resources "/content_pieces", ContentPieceController, only: [:delete]
      live "/content_pieces/:id/edit", ContentPieceLive.Form, :edit

      resources "/content_groups", ContentGroupController,
        only: [:show, :edit, :update, :delete] do
        get "/preview", ContentGroupController, :preview
        live "/content_pieces/new", ContentPieceLive.Form, :new
      end

      live "/catalogs/:id/edit", CatalogLive.Form, :edit

      resources "/catalogs", CatalogController, only: [:show, :delete] do
        resources "/content_groups", ContentGroupController, only: [:new, :create]
      end

      resources "/", CreatorController do
        live "/catalogs/new", CatalogLive.Form, :new
      end
    end
  end
end
