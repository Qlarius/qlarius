defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import Plug.BasicAuth
  import QlariusWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :marketer do
    plug :put_root_layout, html: {QlariusWeb.Layouts, :marketer}

    # Temporary until we've added real auth for marketers
    plug :basic_auth, username: "marketer", password: "password"
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :sponster do
    # NB this only works for controllers, not LiveViews.
    # See QlariusWeb.sponster_live_view/0
    plug :put_layout, html: {QlariusWeb.Layouts, :sponster}
  end

  pipeline :auth_layout do
    plug :put_root_layout, html: {QlariusWeb.Layouts, :auth}
  end

  # ------ MARKETER ROUTES ------

  scope "/", QlariusWeb do
    pipe_through [:browser, :marketer]

    resources "/targets", TargetController
    resources "/media_pieces", MediaPieceController
    resources "/media_sequences", MediaSequenceController, only: [:index, :new, :create]
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

  scope "/", QlariusWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated, :auth_layout]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{QlariusWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", QlariusWeb do
    pipe_through [:browser, :require_authenticated_user, :sponster]

    get "/", PageController, :home

    live_session :require_authenticated_user,
      on_mount: [{QlariusWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/wallet", WalletLive, :index
      live "/ads", AdsLive, :index
      live "/me_file", MeFileLive, :index
      get "/me_file/surveys", MeFileController, :surveys
      live "/me_file/surveys/:survey_id", MeFileSurveyLive, :show
    end

    get "/jump/:id", AdController, :jump
  end

  scope "/", QlariusWeb do
    pipe_through [:browser, :auth_layout]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{QlariusWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
