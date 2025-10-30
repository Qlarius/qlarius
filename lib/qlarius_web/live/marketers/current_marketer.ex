defmodule QlariusWeb.Live.Marketers.CurrentMarketer do
  @moduledoc """
  Helper functions for managing the current marketer selection in LiveViews.
  The current marketer is stored in Phoenix session and used to scope
  campaign management and other marketer-specific operations.
  """

  alias Qlarius.Accounts.Marketers

  @doc """
  on_mount hook that loads the current marketer from connect_params.
  Automatically fetches the full marketer record if an ID is passed from localStorage.
  Available immediately on first render - no flash!
  """
  def on_mount(:load_current_marketer, _params, _session, socket) do
    scope = socket.assigns.current_scope

    current_marketer_id =
      case Phoenix.LiveView.get_connect_params(socket) do
        %{"current_marketer_id" => id_string} when is_binary(id_string) and id_string != "" ->
          String.to_integer(id_string)

        _ ->
          nil
      end

    current_marketer =
      if current_marketer_id do
        try do
          Marketers.get_marketer!(scope, current_marketer_id)
        rescue
          Ecto.NoResultsError -> nil
        end
      else
        nil
      end

    socket =
      socket
      |> Phoenix.Component.assign(:current_marketer_id, current_marketer_id)
      |> Phoenix.Component.assign(:current_marketer, current_marketer)

    {:cont, socket}
  end

  @doc """
  Gets the current marketer ID from socket assigns.
  Returns nil if no marketer is currently selected.
  """
  def get_current_marketer_id(socket) do
    socket.assigns[:current_marketer_id]
  end

  @doc """
  Gets the full marketer record for the current marketer.
  Returns {:ok, marketer} if found, {:error, :not_set} if no current marketer,
  or {:error, :not_found} if the marketer doesn't exist.
  """
  def get_current_marketer(socket, scope) do
    case get_current_marketer_id(socket) do
      nil ->
        {:error, :not_set}

      marketer_id ->
        try do
          marketer = Marketers.get_marketer!(scope, marketer_id)
          {:ok, marketer}
        rescue
          Ecto.NoResultsError -> {:error, :not_found}
        end
    end
  end
end
