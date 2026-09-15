defmodule QlariusWeb.Live.Marketers.CurrentMarketer do
  @moduledoc """
  Helper functions for managing the current marketer selection in LiveViews.
  The current marketer is stored in Phoenix session and used to scope
  campaign management and other marketer-specific operations.
  """

  alias Qlarius.Accounts.Marketers

  @doc """
  on_mount hook that loads the current marketer from connect_params.

  The id arrives from client-controlled localStorage, so it is a *request*, not
  a grant: it is resolved through `Marketers.get_marketer!/2`, which only
  returns orgs the scope may act for. An id the user has no membership in is
  discarded along with the id itself, so downstream code cannot fall back to
  the raw value and act on an org the user does not belong to.
  """
  def on_mount(:load_current_marketer, _params, _session, socket) do
    scope = socket.assigns[:current_scope]

    requested_id =
      case Phoenix.LiveView.get_connect_params(socket) do
        %{"current_marketer_id" => id_string} when is_binary(id_string) and id_string != "" ->
          case Integer.parse(id_string) do
            {id, ""} -> id
            _ -> nil
          end

        _ ->
          nil
      end

    current_marketer = authorized_marketer(scope, requested_id)

    socket =
      socket
      |> Phoenix.Component.assign(:current_marketer_id, current_marketer && current_marketer.id)
      |> Phoenix.Component.assign(:current_marketer, current_marketer)

    {:cont, socket}
  end

  defp authorized_marketer(nil, _id), do: nil
  defp authorized_marketer(_scope, nil), do: nil

  defp authorized_marketer(scope, id) do
    Marketers.get_marketer!(scope, id)
  rescue
    Ecto.NoResultsError -> nil
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
        case authorized_marketer(scope, marketer_id) do
          nil -> {:error, :not_found}
          marketer -> {:ok, marketer}
        end
    end
  end
end
