defmodule QlariusWeb.Dev.LiveViewDebugController do
  use QlariusWeb, :controller

  alias QlariusWeb.LiveViewDebug

  def create(conn, params) do
    if LiveViewDebug.enabled?() do
      LiveViewDebug.record_client(params)
    end

    json(conn, %{ok: true})
  end
end
