defmodule QlariusWeb.Live.CurrentMarketer do
  @moduledoc """
  Helper functions for managing the current marketer selection in LiveViews.
  The current marketer is stored in browser localStorage and used to scope
  campaign management and other marketer-specific operations.
  """

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
          marketer = Qlarius.Accounts.Marketers.get_marketer!(scope, marketer_id)
          {:ok, marketer}
        rescue
          Ecto.NoResultsError -> {:error, :not_found}
        end
    end
  end

  @doc """
  Initializes the current_marketer_id assign on socket mount.
  Should be called in the mount/3 callback or used as an on_mount hook.
  The actual value will be loaded from localStorage via the CurrentMarketer JS hook.
  """
  def on_mount(:init_current_marketer, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_marketer_id, nil)}
  end
end
