defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import QlariusWeb.UserAuth
  import QlariusWeb.Layouts, only: [set_current_path: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug QlariusWeb.Plugs.MobileDetection
    plug :fetch_current_scope_for_user
    plug :allow_iframe
    plug :set_current_path
  end

  pipeline :widgets do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug QlariusWeb.Plugs.MobileDetection
    plug :fetch_current_scope_for_user
    plug :allow_iframe
    plug :set_current_path
  end

  pipeline :admin do
    plug :put_layout, {QlariusWeb.Layouts, :admin}
    # plug QlariusWeb.UserAuth, :require_admin_user # TODO: Add a plug to ensure user is an admin
  end

  pipeline :marketer do
    plug :put_layout, {QlariusWeb.Layouts, :admin}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Based on https://elixirforum.com/t/how-to-embed-a-liveview-via-iframe/65066
  defp allow_iframe(conn, _opts) do
    conn
    # This header is set to SAMEORIGIN by put_secure_browser_headers, which
    # prevents embedding in an iframe.
    |> delete_resp_header("x-frame-options")
    |> put_resp_header(
      "content-security-policy",
      "base-uri 'self'; default-src 'self'; img-src 'self' data: http: https: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' ws://localhost:* wss://localhost:* http://localhost:* https://localhost:* chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen; frame-src 'self' https://www.youtube.com https://youtube.com; frame-ancestors * chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen; upgrade-insecure-requests;"
    )
  end

  # ------ MARKETER ROUTES ------

  scope "/marketer", QlariusWeb do
    pipe_through [:browser, :marketer]

    resources "/media_old", MediaPieceController
    post "/set_current_marketer", CurrentMarketerController, :set

    live_session :marketer,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/campaigns", Live.Marketers.CampaignsManagerLive, :index
      live "/traits", Live.Marketers.TraitsManagerLive, :index
      live "/traits/new", Live.Marketers.TraitsManagerLive, :new_trait_group
      live "/targets", Live.Marketers.TargetsManagerLive, :index
      live "/targets/:id/edit", Live.Marketers.TargetsManagerLive, :edit
      live "/targets/:id/inspect", Live.Marketers.TargetsManagerLive, :inspect
      live "/sequences", Live.Marketers.SequencesManagerLive, :index

      live "/media", Live.Marketers.MediaPieceLive, :index
      live "/media/new", Live.Marketers.MediaPieceLive, :new
      live "/media/:id/edit", Live.Marketers.MediaPieceLive, :edit
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

    live_session :widgets,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/arcade/group/:group_id", Arcade.ArcadeLive
      live "/arqade/:piece_id", Arcade.ArcadeSingleLive
      live "/wallet", WalletLive
      live "/ads_ext_announcer", AdsExtAnnouncerLive
      live "/ads_ext/", AdsExtLive
      live "/ads_ext/:split_code", AdsExtLive
      live "/insta_tip", InstaTipWidgetLive
    end
  end

  scope "/", QlariusWeb do
    pipe_through [:browser]

    live_session :current_scope,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope}
      ] do
      get "/", PageController, :home
      live "/users/settings", UserSettingsLive, :edit
      live "/wallet", WalletLive, :index
      live "/ads", AdsLive, :index
      live "/proxy_users", ProxyUsersLive, :index
      live "/me_file", MeFileLive, :index
      live "/me_file_builder", MeFileBuilderLive, :index
    end

    resources "/tiqits", TiqitController

    get "/jump/:id", AdJumpPageController, :jump
  end

  scope "/creators", QlariusWeb.Creators do
    pipe_through [:browser, :admin]

    live_session :creators,
      on_mount: [
        # {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      resources "/content_pieces", ContentPieceController, only: [:show, :delete]

      live "/content_pieces/:id/edit", ContentPieceLive.Form, :edit
      live "/catalogs/:id/edit", CatalogLive.Form, :edit
      live "/content_groups/:id/edit", ContentGroupLive.Form, :edit

      resources "/content_groups", ContentGroupController, only: [:show, :delete] do
        get "/preview", ContentGroupController, :preview
        live "/content_pieces/new", ContentPieceLive.Form, :new
        post "/add_default_tiqit_classes", ContentGroupController, :add_default_tiqit_classes
      end

      resources "/catalogs", CatalogController, only: [:show, :delete] do
        live "/content_groups/new", ContentGroupLive.Form, :new
        post "/add_default_tiqit_classes", CatalogController, :add_default_tiqit_classes
      end

      resources "/", CreatorController do
        delete "/delete_image", CreatorController, :delete_image
        live "/catalogs/new", CatalogLive.Form, :new
      end
    end
  end

  # ------ ADMIN ROUTES ------
  scope "/admin", QlariusWeb.Admin do
    pipe_through [:browser, :admin]

    # Commented out unimplemented DashboardLive module - route not implemented yet
    # live "/", DashboardLive, :index
    resources "/recipients", RecipientController

    live_session :admin_marketers,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/marketers", MarketerManagerLive, :index
      live "/marketers/new", MarketerManagerLive, :new
      live "/marketers/:id", MarketerManagerLive, :show
      live "/marketers/:id/edit", MarketerManagerLive, :edit
    end

    live_session :admin_trait_categories,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/trait_categories", TraitCategoryManagerLive, :index
      live "/trait_categories/new", TraitCategoryManagerLive, :new
      live "/trait_categories/:id/edit", TraitCategoryManagerLive, :edit
    end

    live_session :admin_ad_categories,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/ad_categories", AdCategoryManagerLive, :index
      live "/ad_categories/new", AdCategoryManagerLive, :new
      live "/ad_categories/:id/edit", AdCategoryManagerLive, :edit
    end

    live_session :admin_survey_categories,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/survey_categories", SurveyCategoryManagerLive, :index
      live "/survey_categories/new", SurveyCategoryManagerLive, :new
      live "/survey_categories/:id/edit", SurveyCategoryManagerLive, :edit
    end
  end
end
