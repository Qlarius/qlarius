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
    plug :fetch_current_scope_for_user
  end

  pipeline :widgets do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    # plug :put_secure_browser_headers, %{"x-frame-options" => "ALLOWALL"}
    plug :fetch_current_scope_for_user
  end

  pipeline :marketer do
    plug :put_root_layout, html: {QlariusWeb.Layouts, :marketer}
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
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{QlariusWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/widgets", QlariusWeb.Widgets do
    pipe_through [:widgets]

    get "/content/:id", ContentController, :show

    live_session :widgets, on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
      live "/arcade/group/:group_id", ArcadeLive
      live "/wallet", WalletLive
    end
  end

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
      get "/me_file/surveys", MeFileController, :surveys
      live "/me_file/surveys/:survey_id", MeFileSurveyLive, :show
      live "/me_file/surveys/:survey_id/:index", MeFileSurveyLive, :show
    end

    get "/jump/:id", AdController, :jump
  end

  scope "/creators", QlariusWeb.Creators do
    pipe_through [:browser, :require_authenticated_user]

    get "/", CreatorController, :redirect_to_content_groups

    live_session :creators, on_mount: [{QlariusWeb.UserAuth, :require_authenticated}] do
      resources "/content_groups", ContentGroupController do
        live "/pieces/new", ContentPieceLive.Form, :new
        live "/pieces/:id/edit", ContentPieceLive.Form, :edit
        resources "/pieces", ContentPieceController, only: [:show, :index, :delete]
      end
    end
  end

  scope "/", QlariusWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{QlariusWeb.UserAuth, :mount_current_scope}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
