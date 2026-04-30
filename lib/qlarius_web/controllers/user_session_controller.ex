defmodule QlariusWeb.UserSessionController do
  use QlariusWeb, :controller

  alias Qlarius.Qlink.Urls
  alias QlariusWeb.UserAuth

  # Honors an optional `?return_to=<local-path>` (or form field of the
  # same name). Used by the Qlink-page logout surface so the visitor
  # lands back on the same Qlink page as an anonymous viewer rather
  # than on `/login`. The path is sanitized to a local path to close
  # open-redirect attack surface; unknown/invalid values fall through
  # to the default `/login` flow with its flash.
  def delete(conn, params) do
    case Urls.sanitize_return_to(Map.get(params, "return_to")) do
      nil ->
        conn
        |> put_flash(:info, "Logged out successfully.")
        |> UserAuth.log_out_user()

      path ->
        UserAuth.log_out_user(conn, to: path)
    end
  end
end
