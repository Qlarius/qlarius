defmodule QlariusWeb.Auth.PopupDoneController do
  @moduledoc """
  Tiny HTML page shown after popup login/register completes.
  Notifies `window.opener` and closes itself.

  When the opener is a widget iframe in a browser that blocks third-party
  cookies, the iframe never sees the session cookie this popup just set.
  So, when the popup was opened with an `opener_origin` the endpoint
  recognises as one of ours, the page also hands the opener a short-lived
  single-use `widget_token` for the session user, posted only to that
  origin. Without a valid `opener_origin` the message carries no token and
  is broadcast to `*` as before.
  """

  use QlariusWeb, :controller

  alias QlariusWeb.Auth.WidgetToken

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def show(conn, params) do
    opener_origin = validated_opener_origin(params["opener_origin"])
    sync_id = validated_sync_id(params["sync_id"])
    widget_token = maybe_widget_token(conn, opener_origin, sync_id)

    message =
      %{type: "qadabra:auth:popup-done"}
      |> maybe_put(:widget_token, widget_token)
      |> Jason.encode!()

    html = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Connected</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        <p>You're connected. You can close this window.</p>
        <script>
          (function () {
            var target = #{Jason.encode!(opener_origin || "*")};
            var hasOrigin = #{Jason.encode!(not is_nil(opener_origin))};
            if (!hasOrigin) {
              // Magic-link logins land here without query params; the
              // Connect page stashed the opener details in this window.
              try {
                var stashed = sessionStorage.getItem("qadabra:popup-opener");
                if (stashed) {
                  var parsed = JSON.parse(stashed);
                  sessionStorage.removeItem("qadabra:popup-opener");
                  if (parsed && parsed.opener_origin) {
                    var q = new URLSearchParams();
                    q.set("opener_origin", parsed.opener_origin);
                    if (parsed.sync_id) q.set("sync_id", parsed.sync_id);
                    window.location.replace("/auth/popup_done?" + q.toString());
                    return;
                  }
                }
              } catch (_e) {}
            }
            try {
              if (window.opener && !window.opener.closed) {
                window.opener.postMessage(#{message}, target);
              }
            } catch (_e) {}
            setTimeout(function () {
              window.close();
            }, 150);
          })();
        </script>
      </body>
    </html>
    """

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp maybe_widget_token(_conn, nil, _sync_id), do: nil

  defp maybe_widget_token(conn, _opener_origin, sync_id) do
    case get_session(conn, :user_token) do
      user_token when is_binary(user_token) and user_token != "" ->
        WidgetToken.sign_authed(user_token, sync_id || get_session(conn, :session_sync_id))

      _ ->
        nil
    end
  end

  # Only origins the endpoint already trusts for LiveView sockets, and
  # only over https (or http on dev hosts), may receive a session token.
  defp validated_opener_origin(origin) when is_binary(origin) do
    uri = URI.parse(origin)

    with true <- uri.scheme in ["https", "http"],
         true <- is_binary(uri.host) and uri.host != "",
         true <- is_nil(uri.path) or uri.path in ["", "/"],
         true <- is_nil(uri.query) and is_nil(uri.fragment),
         true <- uri.scheme == "https" or uri.host in ["localhost", "127.0.0.1", "10.0.2.2"],
         true <- QlariusWeb.Endpoint.check_ws_origin(uri) do
      port = if uri.port in [nil, URI.default_port(uri.scheme)], do: "", else: ":#{uri.port}"
      "#{uri.scheme}://#{uri.host}#{port}"
    else
      _ -> nil
    end
  end

  defp validated_opener_origin(_), do: nil

  defp validated_sync_id(id) when is_binary(id) do
    if Regex.match?(@uuid, id), do: String.downcase(id), else: nil
  end

  defp validated_sync_id(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
