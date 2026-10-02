defmodule QlariusWeb.Live.Marketers.CurrentMarketer do
  @moduledoc """
  Helper functions for managing the current marketer selection in LiveViews.

  The selected marketer id lives in the Phoenix session, written by
  `QlariusWeb.CurrentMarketerController.select/2`. Because the session is
  available on both the static and the connected render, pages render with the
  right marketer from the first paint.
  """

  alias Qlarius.Accounts.Marketers

  @doc """
  on_mount hook that loads the current marketer from the session.

  The stored id is a *request*, not a grant: it is resolved through
  `Marketers.get_marketer!/2`, which only returns orgs the scope may act for. An
  id the user has no membership in is discarded, so downstream code cannot act
  on an org the user does not belong to.
  """
  def on_mount(:load_current_marketer, _params, session, socket) do
    current_marketer = resolve(socket.assigns[:current_scope], session["current_marketer_id"])

    socket =
      socket
      |> Phoenix.Component.assign(:current_marketer_id, current_marketer && current_marketer.id)
      |> Phoenix.Component.assign(:current_marketer, current_marketer)

    {:cont, socket}
  end

  @doc """
  Returns the marketer for `id` if the scope may act for it, otherwise nil.
  Accepts an integer or a numeric string.
  """
  def resolve(nil, _id), do: nil

  def resolve(scope, id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> resolve(scope, int_id)
      _ -> nil
    end
  end

  def resolve(scope, id) when is_integer(id) do
    Marketers.get_marketer!(scope, id)
  rescue
    Ecto.NoResultsError -> nil
  end

  def resolve(_scope, _id), do: nil

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
        case resolve(scope, marketer_id) do
          nil -> {:error, :not_found}
          marketer -> {:ok, marketer}
        end
    end
  end
end
