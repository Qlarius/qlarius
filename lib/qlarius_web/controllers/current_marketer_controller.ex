defmodule QlariusWeb.CurrentMarketerController do
  use QlariusWeb, :controller

  def set(conn, %{"marketer_id" => marketer_id}) do
    marketer_id_int = String.to_integer(marketer_id)

    conn
    |> put_session(:current_marketer_id, marketer_id_int)
    |> json(%{ok: true})
  end
end
