defmodule Qlarius.Campaigns do
  @moduledoc """
  The Campaigns context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Campaigns.{Target, TargetBand}

  #
  # Targets
  #

  @doc """
  Returns the list of targets.
  """
  def list_targets do
    Repo.all(Target)
  end

  @doc """
  Gets a single target.
  Raises `Ecto.NoResultsError` if the Target does not exist.
  """
  def get_target!(id), do: Repo.get!(Target, id)

  @doc """
  Creates a target and its default bullseye target band.
  """
  def create_target(attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, target} <- do_create_target(attrs),
           {:ok, _target_band} <- create_bullseye_target_band(target) do
        target
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_create_target(attrs) do
    %Target{}
    |> Target.changeset(attrs)
    |> Repo.insert()
  end

  defp create_bullseye_target_band(target) do
    %TargetBand{}
    |> TargetBand.changeset(%{
      title: "Bullseye",
      description: "Default target band",
      bullseye: true,
      target_id: target.id
    })
    |> Repo.insert()
  end

  @doc """
  Updates a target.
  """
  def update_target(%Target{} = target, attrs) do
    target
    |> Target.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a target and all its target bands.
  """
  def delete_target(%Target{} = target) do
    Repo.delete(target)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking target changes.
  """
  def change_target(%Target{} = target, attrs \\ %{}) do
    Target.changeset(target, attrs)
  end

  #
  # Target Bands
  #

  @doc """
  Returns the list of target bands for a target.
  """
  def list_target_bands(target_id) do
    TargetBand
    |> where([tb], tb.target_id == ^target_id)
    |> Repo.all()
  end

  @doc """
  Gets a single target band.
  Raises `Ecto.NoResultsError` if the Target band does not exist.
  """
  def get_target_band!(id), do: Repo.get!(TargetBand, id)

  @doc """
  Creates a target band.
  """
  def create_target_band(attrs \\ %{}) do
    %TargetBand{}
    |> TargetBand.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a target band.
  """
  def update_target_band(%TargetBand{} = target_band, attrs) do
    target_band
    |> TargetBand.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a target band.
  """
  def delete_target_band(%TargetBand{} = target_band) do
    Repo.delete(target_band)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking target band changes.
  """
  def change_target_band(%TargetBand{} = target_band, attrs \\ %{}) do
    TargetBand.changeset(target_band, attrs)
  end
end
