defmodule QlariusWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use QlariusWeb, :controller
      use QlariusWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: QlariusWeb.Layouts]

      use Gettext, backend: QlariusWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {QlariusWeb.Layouts, :app}

      unquote(html_helpers())
      unquote(socket_helpers())
    end
  end

  # same as live_view/0 except setting a different app layout. I'd rather do
  # this in the router so I don't have to repeat it in each individual
  # LiveView, but can't figure out how :'(
  def sponster_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {QlariusWeb.Layouts, :sponster}

      unquote(html_helpers())
      unquote(socket_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
      unquote(socket_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: QlariusWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import QlariusWeb.CoreComponents

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: QlariusWeb.Endpoint,
        router: QlariusWeb.Router,
        statics: QlariusWeb.static_paths()
    end
  end

  defp socket_helpers do
    quote do
      def ok(socket) do
        {:ok, socket}
      end

      def ok(socket, opts) do
        {:ok, socket, opts}
      end

      def noreply(socket), do: {:noreply, socket}
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
