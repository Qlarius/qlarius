defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import QlariusWeb.UserAuth,
    only: [
      fetch_current_scope_for_user: 2,
      redirect_if_user_is_authenticated: 2,
      require_authenticated_user: 2
    ]

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
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ------ MARKETER ROUTES ------

  pipeline :marketer do
    plug :put_root_layout, html: {QlariusWeb.Layouts, :marketer}
  end

  scope "/", QlariusWeb do
    pipe_through [:browser, :marketer]

    # resources "/targets", TargetController
    resources "/media_pieces", MediaPieceController
    # resources "/media_sequences", MediaSequenceController, only: [:index, :new, :create]
    # live "/trait_groups", TraitGroupLive.Index, :index
    # live "/trait_manager", TraitManagerLive.Index, :index

    # live "/trait_categories", TraitCategoryLive.Index, :index
    # live "/trait_categories/new", TraitCategoryLive.Index, :new
    # live "/trait_categories/:id/edit", TraitCategoryLive.Index, :edit

    # live "/survey_manager/new/:category_id", SurveyManagerLive, :new
    # live "/survey_manager/edit/:id", SurveyManagerLive, :edit
    # live "/survey_manager/:id", SurveyManagerLive, :show
    # live "/survey_manager", SurveyManagerLive, :index
  end

  # ------ /MARKETER ROUTES ------

  pipeline :auth_layout do
    plug :put_root_layout, html: {QlariusWeb.Layouts, :auth}
  end

  # Main routes
  scope "/", QlariusWeb do
    pipe_through [:browser]

    get "/", PageController, :home
    live "/me", MeFileLive
    live "/ads", AdsLive
    live "/wallet", WalletLive
    get "/me_file/surveys", MeFileController, :surveys
    live "/me_file/surveys/:survey_id", MeFileSurveyLive, :show
    live "/me_file/surveys/:survey_id/:index", MeFileSurveyLive, :show

    live "/ads_ext/", AdsExtLive
    live "/ads_ext/:split_code", AdsExtLive
  end

  # Widget routes
  scope "/widgets", QlariusWeb.Widgets do
    pipe_through [:widgets]

    get "/content/:id", ContentController, :show
    live "/arcade/group/:group_id", ArcadeLive
    live "/wallet", WalletLive
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:qlarius, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QlariusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # scope "/", QlariusWeb do
  #   pipe_through [:browser, :redirect_if_user_is_authenticated, :auth_layout]

  #   live_session :redirect_if_user_is_authenticated,
  #     on_mount: [{QlariusWeb.UserAuth, :redirect_if_user_is_authenticated}] do
  #     live "/users/register", UserRegistrationLive, :new
  #     live "/users/log_in", UserLoginLive, :new
  #     live "/users/reset_password", UserForgotPasswordLive, :new
  #     live "/users/reset_password/:token", UserResetPasswordLive, :edit
  #   end

  #   post "/users/log_in", UserSessionController, :create
  # end

  scope "/", QlariusWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{QlariusWeb.UserAuth, :require_authenticated}] do
      get "/", PageController, :home
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/wallet", WalletLive, :index
      live "/ads", AdsLive, :index
      live "/me_file", MeFileLive, :index
      live "/proxy_users", ProxyUsersLive, :index
      get "/me_file/surveys", MeFileController, :surveys
      live "/me_file/surveys/:survey_id", MeFileSurveyLive, :show
      live "/me_file/surveys/:survey_id/:index", MeFileSurveyLive, :show
      get "/arcade", ContentController, :groups
      live "/admin/content/new", Marketers.ContentLive.Form, :new
      live "/admin/content/:id/edit", Marketers.ContentLive.Form, :edit
      resources "/admin/content", Marketers.ContentController, only: [:show, :index, :delete]
    end

    get "/jump/:id", AdController, :jump
  end

  # scope "/", QlariusWeb do
  #   pipe_through [:browser, :auth_layout]

  #   delete "/users/log_out", UserSessionController, :delete

  #   live_session :current_user,
  #     on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
  #     live "/users/confirm/:token", UserConfirmationLive, :edit
  #     live "/users/confirm", UserConfirmationInstructionsLive, :new
  #   end
  # end

end
