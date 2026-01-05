defmodule Qlarius.Maintenance.FixMissingMobileNumbers do
  @moduledoc """
  Fixes users who registered but had their mobile numbers not saved due to the
  registration_changeset bug.

  Usage in IEx:
      Qlarius.Maintenance.FixMissingMobileNumbers.fix_user(200393, "+15551234567")

  Or to check which users are affected:
      Qlarius.Maintenance.FixMissingMobileNumbers.find_users_without_mobile()
  """

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Accounts.User

  def find_users_without_mobile do
    query =
      from u in User,
        where: is_nil(u.mobile_number_encrypted),
        select: %{
          id: u.id,
          alias: u.alias,
          inserted_at: u.inserted_at,
          last_sign_in_at: u.last_sign_in_at
        }

    users = Repo.all(query)

    IO.puts("\n=== Users without mobile numbers ===")
    IO.puts("Found #{length(users)} users")

    Enum.each(users, fn user ->
      IO.puts(
        "ID: #{user.id}, Alias: #{user.alias}, Registered: #{user.inserted_at}, Last login: #{user.last_sign_in_at}"
      )
    end)

    users
  end

  def fix_user(user_id, mobile_number) do
    user = Repo.get!(User, user_id)

    IO.puts("\n=== Fixing user #{user_id} (#{user.alias}) ===")
    IO.puts("Current mobile_number_encrypted: #{inspect(user.mobile_number_encrypted)}")
    IO.puts("Current mobile_number_hash: #{inspect(user.mobile_number_hash)}")
    IO.puts("New mobile number: #{mobile_number}")

    changeset =
      User.registration_changeset(user, %{mobile_number: mobile_number})

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        IO.puts("\n✅ SUCCESS!")

        IO.puts(
          "Updated mobile_number_encrypted: #{inspect(updated_user.mobile_number_encrypted)}"
        )

        IO.puts(
          "Updated mobile_number_hash: #{inspect(updated_user.mobile_number_hash |> Base.encode16())}"
        )

        {:ok, updated_user}

      {:error, changeset} ->
        IO.puts("\n❌ FAILED!")
        IO.puts("Errors: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def fix_user_dry_run(user_id, mobile_number) do
    user = Repo.get!(User, user_id)

    IO.puts("\n=== DRY RUN: Would fix user #{user_id} (#{user.alias}) ===")
    IO.puts("Current mobile_number_encrypted: #{inspect(user.mobile_number_encrypted)}")
    IO.puts("Current mobile_number_hash: #{inspect(user.mobile_number_hash)}")
    IO.puts("New mobile number: #{mobile_number}")

    changeset = User.registration_changeset(user, %{mobile_number: mobile_number})

    if changeset.valid? do
      IO.puts("\n✅ Changeset is valid")

      IO.puts(
        "Would set mobile_number_encrypted to: #{inspect(Ecto.Changeset.get_change(changeset, :mobile_number_encrypted))}"
      )

      hash = Ecto.Changeset.get_change(changeset, :mobile_number_hash)

      IO.puts(
        "Would set mobile_number_hash to: #{if hash, do: Base.encode16(hash), else: "unchanged"}"
      )

      {:ok, :dry_run}
    else
      IO.puts("\n❌ Changeset is invalid")
      IO.puts("Errors: #{inspect(changeset.errors)}")
      {:error, changeset}
    end
  end
end
