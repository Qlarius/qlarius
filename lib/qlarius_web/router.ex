defmodule QlariusWeb.Router do
  use QlariusWeb, :router

  import QlariusWeb.UserAuth
  import QlariusWeb.Layouts, only: [set_current_path: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug QlariusWeb.Plugs.StorePWASession
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

  pipeline :share_fork do
    plug QlariusWeb.Plugs.EnsureShareFork
  end

  # Surface-only pipeline for the in-app-browser escape feature. Runs
  # `InAppBrowserDetection` and nothing else, and is attached **only**
  # to the Qlink route scopes below — the only surface that renders
  # the escape UI (`QlinkPage.Show`). Keeps the plug out of the shared
  # `:browser`/`:widgets` pipelines so it can't touch the main-app
  # session cookie on unrelated hosts, and makes the "this runs on
  # Qlink pages" intent explicit at the router level. The plug also
  # carries an internal host guard as a second line of defense; see
  # `QlariusWeb.Plugs.InAppBrowserDetection` for details.
  pipeline :iab_detection do
    plug QlariusWeb.Plugs.InAppBrowserDetection
  end

  # Anonymous browser pipeline for the public Qlink share surface
  # (qlinkin.bio). Deliberately omits `:fetch_current_scope_for_user` and
  # the PWA/referral/mobile session-mutating plugs so responses can be
  # edge-cached by Cloudflare regardless of whether a visitor has a stale
  # session cookie from qadabra.app. Pair this in the router with
  # `{QlariusWeb.UserAuth, :mount_anonymous_scope}` in the live_session's
  # `on_mount` so LiveView also starts with `current_scope: nil`.
  pipeline :browser_anon do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QlariusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :allow_iframe
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
  # CSP lives in QlariusWeb.SecurityHeaders; this plug only adds the
  # x-frame-options strip needed for routes that serve iframeable content.
  defp allow_iframe(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header(
      "content-security-policy",
      QlariusWeb.SecurityHeaders.content_security_policy()
    )
  end

  # ------ QLINK SHARE HOST (qlinkin.bio) ------
  #
  # Interactive, auth-capable view of a creator's Qlink page. Uses the
  # full `:browser` pipeline so the host-scoped session cookie (see
  # `QlariusWeb.Plugs.HostAwareSession` — qlinkin.bio cookies stay
  # host-scoped, they are NOT shared with `.qadabra.app`) is read and
  # `current_scope` is populated for any visitor who has signed in on
  # qlinkin.bio before. Anonymous visitors still get the page; the
  # `AuthSheet` LiveComponent (gated behind
  # `:auth_sheet[:on_qlinkin_bio]`) authenticates them in place via
  # `POST /auth/finalize_session` below without a cross-host redirect.
  #
  # Prior to B6 this scope used the `:browser_anon` pipeline +
  # `:mount_anonymous_scope` hook so all responses were cacheable at
  # the Cloudflare edge. That changed in B6: responses on this host
  # can now carry `Set-Cookie` headers. **Production rollout of the
  # AuthSheet on this host (setting `on_qlinkin_bio: true`) requires
  # a Cloudflare cache rule that bypasses cache when the
  # `_qlarius_key` cookie is present on the request**, otherwise
  # authed visitors may be served cached anonymous responses.
  # See `docs/qlink_auth_refactor_plan.md` §B6.
  #
  # The catch-all `match :* /*path` at the bottom ensures any non-Qlink
  # path on qlinkin.bio (including the bare root) redirects to the
  # Qadabra marketing site's Qlink landing page. That keeps this host
  # single-purpose and prevents accidental exposure of app routes.
  #
  # **Multi-domain routing:** Declarations that exist only in the
  # unscoped `scope` (e.g. `/jump/...` next to `AdsLive`) are **not**
  # reached for this host if the path is matched here first (including
  # by the catch-all). Any user-facing same-origin path used on
  # qlinkin (links, `fetch`, CSRF) must be mounted **in this `host:`
  # block** before `match :* /*path` — or use an absolute URL to
  # another host with a separate auth design.
  #
  # IMPORTANT: Must be defined BEFORE any unrestricted (non-`host:`)
  # scope that also claims `/` (e.g. the HiLive `/` route), because
  # Phoenix router matches in definition order.

  # AuthSheet `POST /auth/finalize_session` for qlinkin.bio. Declared
  # BEFORE the main qlinkin.bio scope below so its `match :* /*path`
  # catch-all doesn't shadow the path. Uses the JSON `:auth_finalize`
  # pipeline (not `:browser`) because the client is a JS `fetch()`
  # with `Accept: application/json`.
  scope "/auth", QlariusWeb.Auth, host: ["qlinkin.bio", "www.qlinkin.bio"] do
    pipe_through [:auth_finalize]

    post "/finalize_session", FinalizeSessionController, :create
  end

  scope "/", QlariusWeb, host: ["qlinkin.bio", "www.qlinkin.bio"] do
    pipe_through [:browser, :iab_detection]

    live_session :public_qlinkin_bio,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.InAppBrowserMount, :assign_in_app_browser}
      ] do
      live "/@:alias", QlinkPage.Show, :show
    end

    # Logout explicitly mounted for qlinkin.bio because the catch-all
    # below would otherwise shadow the non-host-scoped `/logout`
    # declared later in the router.
    delete "/logout", UserSessionController, :delete

    # Three-tap ad jump page + `POST /jump/collect` (same as main app, lines ~405–406).
    # `~p"/jump/…"` in OfferHTML is same-host; see **Multi-domain routing** note above —
    # the catch-all would otherwise eat `/jump/*` on this host. AdJumpPageController.
    scope "/" do
      # Parent `scope` is `QlariusWeb` — unqualified controller names resolve under it.
      # Parent already has `pipe_through :browser` — add auth only
      # (Phoenix disallows listing :browser again in a nested scope).
      pipe_through [:require_auth]

      get "/jump/:id", AdJumpPageController, :jump
      post "/jump/collect", AdJumpPageController, :collect
    end

    get "/", QlinkRedirectController, :landing
    match :*, "/*path", QlinkRedirectController, :not_found
  end

  # ------ QLINK INTERACT HOST (qlink.qadabra.app) ------
  #
  # Authed/interactive mirror of the Qlink page. Uses the full `:browser`
  # pipeline so the shared `.qadabra.app` session cookie is read and
  # `current_scope` is populated for logged-in visitors. Anonymous
  # visitors that reach this host still get the same page but rendered
  # with an "Connect your wallet" CTA that routes to the standard
  # Qadabra login flow.
  #
  # `localhost` and `127.0.0.1` keep the `/@alias` route reachable in
  # local dev; `qlarius.gigalixirapp.com` keeps it working on the
  # existing Gigalixir hostname during the DNS migration.
  scope "/", QlariusWeb,
    host: [
      "qlink.qadabra.app",
      "localhost",
      "127.0.0.1",
      "qlarius.gigalixirapp.com"
    ] do
    pipe_through [:browser, :iab_detection]

    live_session :public_qlink_authed,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.InAppBrowserMount, :assign_in_app_browser}
      ] do
      live "/@:alias", QlinkPage.Show, :show
    end
  end

  # ------ APEX → QLINK INTERACT REDIRECT ------
  #
  # The apex host (qadabra.app) is reserved for the main authed app.
  # Qlink pages are canonical under the qlink.qadabra.app subdomain, but
  # visitors sometimes type or paste links against the apex. Rather than
  # 404, send them to the canonical interact URL (which preserves
  # session because it shares the `.qadabra.app` cookie domain).
  scope "/", QlariusWeb, host: ["qadabra.app", "www.qadabra.app"] do
    pipe_through [:browser_anon]

    get "/@:alias", QlinkRedirectController, :to_interact
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

      post "/lv-debug", QlariusWeb.Dev.LiveViewDebugController, :create

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
        {QlariusWeb.Layouts, :set_current_path},
        # Seed `@base_path = "/widgets"` for every LV in this
        # scope. Arcade LVs read it to build same-scope internal
        # links (e.g. `#{@base_path}/content/123`). Previously we
        # derived this from `handle_params`'s URI arg, but that
        # callback is forbidden on child LiveViews, which now
        # matter because `ArcadeLive` is also rendered inline via
        # `live_render/3` from Qlink pages.
        {QlariusWeb.Layouts, {:set_base_path, "/widgets"}}
      ] do
      live "/arqade", Arcade.ArqadeDiscoveryLive
      live "/arqade/creator/:creator_id", Arcade.ArqadeCreatorLive
      live "/arqade/group/:group_id", Arcade.ArcadeLive
      live "/arqade/catalog/:catalog_id", Arcade.ArcadeCatalogLive
      live "/arqade/:piece_id", Arcade.ArcadeSingleLive
      live "/wallet", WalletLive
      live "/ads_ext/", AdsExtLive
      live "/ads_ext/:split_code", AdsExtLive
      live "/insta_tip", InstaTipWidgetLive
    end
  end

  scope "/", QlariusWeb do
    pipe_through [:auto_login]

    get "/auto_login/:token", AutoLoginController, :create
  end

  # AuthSheet in-place auth completion endpoint. Uses a bespoke pipeline
  # instead of `:browser` because the client is a JS `fetch()` with
  # `Accept: application/json`, which `plug :accepts, ["html"]` would
  # reject with a 406. The session/CSRF/cookie-host machinery from
  # `:browser` is inlined here; layout and live-flash are skipped since
  # the controller returns 204 (success) or a small JSON error body.
  # See `docs/qlink_auth_refactor_plan.md` §5.9. Also mounted on the
  # qlinkin.bio host scope above (B6) so the AuthSheet's `fetch` can
  # target the same-origin URL on that host.
  pipeline :auth_finalize do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  scope "/auth", QlariusWeb.Auth do
    pipe_through [:auth_finalize]

    post "/finalize_session", FinalizeSessionController, :create
  end

  scope "/api", QlariusWeb do
    pipe_through [
      :api,
      :fetch_session,
      :fetch_current_scope_for_user,
      :require_authenticated_user
    ]

    get "/push/vapid-public-key", PushController, :vapid_public_key
    post "/push/subscribe", PushController, :subscribe
    post "/push/unsubscribe", PushController, :unsubscribe
    post "/push/track-click", PushController, :track_click

    get "/extension/ad_count", ExtensionController, :ad_count
  end

  # Dynamic manifest for PWA - includes referral code in start_url
  scope "/", QlariusWeb do
    pipe_through [:browser]

    get "/app-manifest.webmanifest", ManifestController, :show
  end

  scope "/", QlariusWeb do
    pipe_through [:browser, :iab_detection, :share_fork]

    live_session :public_tiqit_arqade,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.GetUserIP, :assign_ip},
        {QlariusWeb.InAppBrowserMount, :assign_in_app_browser},
        {QlariusWeb.Layouts, {:set_base_path, "/tiqit"}}
      ] do
      live "/tiqit/arqade", Widgets.Arcade.ArqadeDiscoveryLive
      live "/tiqit/arqade/catalog/:catalog_id", Widgets.Arcade.ArcadeCatalogLive
      live "/tiqit/arqade/creator/:creator_id", Widgets.Arcade.ArqadeCreatorLive
      live "/tiqit/arqade/piece/:piece_id", Widgets.Arcade.ArcadeSingleLive
      live "/tiqit/arqade/:content_group_id", TiqitArqadeLive, :show
      live "/tiqit/arqade/:content_group_id/:content_piece_id", TiqitArqadeLive, :show
      live "/tiqit/gift/:token", TiqitArqadeLive, :gift
      live "/tiqit/share/:token", TiqitArqadeLive, :share
    end
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
        {QlariusWeb.PWAInstallHooks, :require_pwa_on_mobile},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/home", HomeLive, :index
      live "/settings", UserSettingsLive, :index
      live "/wallet", WalletLive, :index
      live "/tiqits", TiqitLive, :index

      # Arqade content pages — main app equivalents of /widgets/arqade/...
      # These share the same LiveView modules as the widget versions.
      # @base_path is set at mount to control internal link generation
      # so navigation stays within the correct context (app vs widget).
      # More specific routes must come before the catch-all /arqade/:piece_id.
      live "/content/:id", Widgets.ContentLive
      live "/arqade", Widgets.Arcade.ArqadeDiscoveryLive
      live "/arqade/creator/:creator_id", Widgets.Arcade.ArqadeCreatorLive
      live "/arqade/group/:group_id", Widgets.Arcade.ArcadeLive
      live "/arqade/catalog/:catalog_id", Widgets.Arcade.ArcadeCatalogLive
      live "/arqade/:piece_id", Widgets.Arcade.ArcadeSingleLive
      live "/ads", AdsLive, :index
      live "/referrals", ReferralsLive, :index
      live "/proxy_users", ProxyUsersLive, :index
      live "/me_file", MeFileLive, :index
      live "/me_file_builder", MeFileBuilderLive, :index

      # Test/Design routes
      live "/test/slide-to-collect", SlideToCollectTestLive, :index

      # Creator dashboard routes
      live "/creators", CreatorDashboard.Index, :index
      live "/creators/new", CreatorDashboard.Index, :new
      live "/creators/:id", CreatorDashboard.Show, :show
      live "/creators/:id/edit", CreatorDashboard.Show, :edit
      live "/creators/:id/referrals", CreatorDashboard.Referrals, :index

      # Creator catalog/content routes (migrated from controllers)
      live "/creators/:creator_id/catalogs/new", Creators.CatalogLive.Form, :new
      live "/creators/catalogs/:id", Creators.CatalogLive.Show, :show
      live "/creators/catalogs/:id/edit", Creators.CatalogLive.Form, :edit

      live "/creators/catalogs/:catalog_id/content_groups/new",
           Creators.ContentGroupLive.Form,
           :new

      live "/creators/content_groups/:id", Creators.ContentGroupLive.Show, :show
      live "/creators/content_groups/:id/edit", Creators.ContentGroupLive.Form, :edit
      live "/creators/content_groups/:id/preview", Creators.ContentGroupLive.Preview, :show

      live "/creators/content_groups/:content_group_id/content_pieces/new",
           Creators.ContentPieceLive.Form,
           :new

      live "/creators/content_groups/:content_group_id/youtube_import",
           Creators.ContentGroupLive.YoutubeImport,
           :index

      live "/creators/content_pieces/:id", Creators.ContentPieceLive.Show, :show
      live "/creators/content_pieces/:id/edit", Creators.ContentPieceLive.Form, :edit

      # Qlink Page routes
      live "/creators/:creator_id/qlink_pages/new", Creators.QlinkPageLive.Form, :new
      live "/creators/qlink_pages/:id/edit", Creators.QlinkPageLive.Form, :edit
    end

    # The public Qlink `/@:alias` route now lives in host-scoped blocks
    # above (qlinkin.bio anon + qlink.qadabra.app authed). It was moved
    # out of this `:require_auth` scope so anonymous visitors are no
    # longer redirected to /login when viewing a share URL.

    get "/jump/:id", AdJumpPageController, :jump
    post "/jump/collect", AdJumpPageController, :collect
  end

  scope "/creators_cont", QlariusWeb.Creators do
    pipe_through [:browser, :admin]

    live_session :creators,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
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
      live "/content_groups/:content_group_id/content_pieces/new", ContentPieceLive.Form, :new

      post "/content_groups/:content_group_id/add_default_tiqit_classes",
           ContentGroupController,
           :add_default_tiqit_classes

      live "/catalogs/:catalog_id/content_groups/new", ContentGroupLive.Form, :new

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
    get "/traits_index", TraitsIndexController, :index
    get "/mefile_tags_index", MeFileTagsIndexController, :index
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

    live_session :admin_sponster_ledger,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/sponster_ledger", SponsterLedgerLive, :index
    end

    live_session :admin_mecp_access_log,
      on_mount: [
        {QlariusWeb.UserAuth, :mount_current_scope},
        {QlariusWeb.Layouts, :set_current_path}
      ] do
      live "/mecp_access_log", MeCPAccessLogLive, :index
    end
  end
end
