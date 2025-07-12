defmodule Qlarius.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any marketer changes.
  """
  def subscribe_marketer(%Scope{} = _scope) do
    raise "TODO"
  end

  @doc """
  Returns the list of marketers.

  ## Examples

      iex> list_marketers(scope)
      [%Marketer{}, ...]

  """
  def list_marketers(%Scope{} = _scope) do
    raise "TODO"
  end

  @doc """
  Gets a single marketer.

  Raises if the Marketer does not exist.

  ## Examples

      iex> get_marketer!(scope, 123)
      %Marketer{}

  """
  def get_marketer!(%Scope{} = _scope, id), do: raise("TODO")

  @doc """
  Creates a marketer.

  ## Examples

      iex> create_marketer(scope, %{field: value})
      {:ok, %Marketer{}}

      iex> create_marketer(scope, %{field: bad_value})
      {:error, ...}

  """
  def create_marketer(%Scope{} = _scope, attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a marketer.

  ## Examples

      iex> update_marketer(scope, marketer, %{field: new_value})
      {:ok, %Marketer{}}

      iex> update_marketer(scope, marketer, %{field: bad_value})
      {:error, ...}

  """
  def update_marketer(%Scope{} = _scope, %Marketer{} = marketer, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Marketer.

  ## Examples

      iex> delete_marketer(scope, marketer)
      {:ok, %Marketer{}}

      iex> delete_marketer(scope, marketer)
      {:error, ...}

  """
  def delete_marketer(%Scope{} = _scope, %Marketer{} = marketer) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking marketer changes.

  ## Examples

      iex> change_marketer(scope, marketer)
      %Todo{...}

  """
  def change_marketer(%Scope{} = _scope, %Marketer{} = marketer, _attrs \\ %{}) do
    raise "TODO"
  end
end
