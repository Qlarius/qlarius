defmodule QlariusWeb.Plugs.InAppBrowserDetection do
  @moduledoc false

  import Plug.Conn

  alias Qlarius.Browsers.InAppClassifier

  @session_key "qlarius_iab"

  def init(opts), do: opts

  def call(conn, _opts) do
    cfg = Application.get_env(:qlarius, :in_app_browser_escape, [])

    if Keyword.get(cfg, :enabled, false) do
      run_detection(conn)
    else
      conn
      |> assign(:in_app_browser, nil)
      |> delete_session(@session_key)
    end
  end

  defp run_detection(conn) do
    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""

    case InAppClassifier.classify(user_agent) do
      nil ->
        conn
        |> assign(:in_app_browser, nil)
        |> delete_session(@session_key)

      %{family: family, confidence: confidence, os: os} = result ->
        session_payload = %{
          "family" => Atom.to_string(family),
          "confidence" => Atom.to_string(confidence),
          "os" => Atom.to_string(os)
        }

        conn
        |> assign(:in_app_browser, result)
        |> put_session(@session_key, session_payload)
    end
  end
end
