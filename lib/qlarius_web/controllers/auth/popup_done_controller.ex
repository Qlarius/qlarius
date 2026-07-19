defmodule QlariusWeb.Auth.PopupDoneController do
  @moduledoc """
  Tiny HTML page shown after popup login/register completes.
  Notifies `window.opener` and closes itself.
  """

  use QlariusWeb, :controller

  def show(conn, _params) do
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
            try {
              if (window.opener && !window.opener.closed) {
                window.opener.postMessage(
                  { type: "qadabra:auth:popup-done" },
                  "*"
                );
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
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end
