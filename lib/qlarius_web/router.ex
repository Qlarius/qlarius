defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import QlariusWeb.UserAuth
  import QlariusWeb.Layouts, only: [set_current_path: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug QlariusWeb.Plugs.StoreReferralCode
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
    plug :require_authenticated_user
    plug :require_admin_user
  end

  pipeline :marketer do
    plug :put_layout, {QlariusWeb.Layouts, :admin}
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auto_login do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :put_secure_browser_headers
  end

  # Based on https://elixirforum.com/t/how-to-embed-a-liveview-via-iframe/65066
  defp allow_iframe(conn, _opts) do
    csp =
      "base-uri 'self'; default-src 'self'; img-src 'self' data: http: https: blob:; media-src 'self' https://*.s3.us-east-1.amazonaws.com https://*.s3.amazonaws.com; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' ws: wss: http: https: chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen; frame-src 'self' https://www.youtube.com https://youtube.com; frame-ancestors * chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen;"

    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header("content-security-policy", csp)
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
    pipe_through [:auto_login]

    get "/auto_login/:token", AutoLoginController, :create
  end

  scope "/api", QlariusWeb do
    pipe_through [:api, :fetch_session, :fetch_current_scope_for_user, :require_authenticated_user]

    get "/push/vapid-public-key", PushController, :vapid_public_key
    post "/push/subscribe", PushController, :subscribe
    post "/push/unsubscribe", PushController, :unsubscribe
    post "/push/track-click", PushController, :track_click
  end

  scope "/", QlariusWeb do
    pipe_through [:browser]

    live_session :hi,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope}
      ] do
      live "/", HiLive, :index
      live "/hi", HiLive, :index
    end

    live_session :public,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.UserAuth, :redirect_if_user_is_authenticated}
      ] do
      live "/login", LoginLive, :index
      live "/register", RegistrationLive, :index
    end

    post "/login/create_session", UserSessionCreateController, :create
    delete "/logout", UserSessionController, :delete
  end

  # Protected routes requiring authentication
  scope "/", QlariusWeb do
    pipe_through [:browser, :require_auth]

    live_session :current_scope,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.UserAuth, :ensure_authenticated},
        {QlariusWeb.UserAuth, :require_initialized_mefile},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/home", HomeLive, :index
      live "/settings", UserSettingsLive, :index
      live "/wallet", WalletLive, :index
      live "/ads", AdsLive, :index
      live "/referrals", ReferralsLive, :index
      live "/proxy_users", ProxyUsersLive, :index
      live "/me_file", MeFileLive, :index
      live "/me_file_builder", MeFileBuilderLive, :index

      # Creator dashboard routes
      live "/creators", CreatorDashboard.Index, :index
      live "/creators/new", CreatorDashboard.Index, :new
      live "/creators/:id", CreatorDashboard.Show, :show
      live "/creators/:id/edit", CreatorDashboard.Show, :edit
      live "/creators/:id/referrals", CreatorDashboard.Referrals, :index

      # Creator catalog/content routes (migrated from controllers)
      live "/creators/:id/catalogs/new", Creators.CatalogLive.Form, :new
      live "/creators/catalogs/:id", Creators.CatalogLive.Show, :show
      live "/creators/catalogs/:id/edit", Creators.CatalogLive.Form, :edit
      live "/creators/catalogs/:id/content_groups/new", Creators.ContentGroupLive.Form, :new

      live "/creators/content_groups/:id", Creators.ContentGroupLive.Show, :show
      live "/creators/content_groups/:id/edit", Creators.ContentGroupLive.Form, :edit
      live "/creators/content_groups/:id/preview", Creators.ContentGroupLive.Preview, :show
      live "/creators/content_groups/:id/content_pieces/new", Creators.ContentPieceLive.Form, :new

      live "/creators/content_pieces/:id", Creators.ContentPieceLive.Show, :show
      live "/creators/content_pieces/:id/edit", Creators.ContentPieceLive.Form, :edit

      # Qlink Page routes
      live "/creators/:creator_id/qlink_pages/new", Creators.QlinkPageLive.Form, :new
      live "/creators/qlink_pages/:id/edit", Creators.QlinkPageLive.Form, :edit
    end

    # Public Qlink page route (no auth required)
    live "/@:alias", QlinkPage.Show, :show

    resources "/tiqits", TiqitController

    get "/jump/:id", AdJumpPageController, :jump
  end

  scope "/creators_cont", QlariusWeb.Creators do
    pipe_through [:browser, :admin]

    live_session :creators,
      on_mount: [
        # {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/content_pieces/:id", ContentPieceLive.Show, :show
      live "/content_pieces/:id/edit", ContentPieceLive.Form, :edit

      live "/catalogs/:id", CatalogLive.Show, :show
      live "/catalogs/:id/edit", CatalogLive.Form, :edit

      post "/catalogs/:catalog_id/add_default_tiqit_classes",
           CatalogController,
           :add_default_tiqit_classes

      live "/content_groups/:id", ContentGroupLive.Show, :show
      live "/content_groups/:id/edit", ContentGroupLive.Form, :edit
      live "/content_groups/:id/preview", ContentGroupLive.Preview, :show
      live "/content_groups/:id/content_pieces/new", ContentPieceLive.Form, :new

      post "/content_groups/:content_group_id/add_default_tiqit_classes",
           ContentGroupController,
           :add_default_tiqit_classes

      live "/catalogs/:id/content_groups/new", ContentGroupLive.Form, :new

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

    live_session :admin_recipients,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/recipients/:id/referrals", RecipientReferralsLive, :index
    end

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

    live_session :admin_traits,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/traits", TraitManagerLive, :index
    end

    live_session :admin_surveys,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/surveys", SurveyManagerLive, :index
    end

    live_session :admin_alias_words,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/alias_words", AliasWordsLive, :index
    end

    live_session :admin_global_variables,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/global_variables", GlobalVariablesLive, :index
    end

    live_session :admin_mefile_inspector,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/mefile_inspector", MeFileInspectorLive, :index
      live "/mefile_inspector/:id", MeFileInspectorLive.Show, :show
    end
  end
end
