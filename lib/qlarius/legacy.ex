defmodule Qlarius.Legacy do
  @moduledoc """
  Context for interacting with the legacy Rails database.
  """

  import Ecto.Query

  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{User, MeFile}

  def get_user(id) do
    LegacyRepo.get(User, id)
  end

  def get_user_by_email(email) do
    LegacyRepo.get_by(User, email: email)
  end

  def list_users do
    LegacyRepo.all(User)
  end

  def get_me_file(id) do
    LegacyRepo.get(MeFile, id)
    |> LegacyRepo.preload([:user, :ledger_header])
  end

  def get_user_me_file(user_id) do
    MeFile
    |> where([m], m.user_id == ^user_id)
    |> LegacyRepo.one()
    |> LegacyRepo.preload([:ledger_header])
  end

  def list_me_files do
    LegacyRepo.all(MeFile)
    |> LegacyRepo.preload([:user])
  end
end
