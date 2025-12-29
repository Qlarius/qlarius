defmodule Qlarius.Maintenance.SwapMobileNumbers do
  @moduledoc """
  Maintenance utility to swap mobile numbers between two users.

  Use case: Transfer a validated mobile number from one user account to another.

  ## Usage

  In IEx:

      iex> alias Qlarius.Maintenance.SwapMobileNumbers
      iex> SwapMobileNumbers.swap("user_alias_1", "user_alias_2")

  Via Mix:

      mix run -e "Qlarius.Maintenance.SwapMobileNumbers.swap(\"user1\", \"user2\")"

  ## What Gets Swapped

  - `mobile_number` (plain text)
  - `mobile_number_encrypted` (encrypted)
  - `mobile_number_hash` (hash for unique constraint)
  - `phone_verified_at` (verification timestamp)

  ## Safety

  - Uses a database transaction for atomicity
  - Validates both users exist before attempting swap
  - No data is deleted until successful save
  - Detailed error reporting
  """

  require Logger
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Accounts.User

  @doc """
  Swaps mobile numbers between two users identified by their aliases.

  ## Examples

      iex> swap("alice", "bob")
      {:ok, %{user1: %User{}, user2: %User{}}}

      iex> swap("alice", "nonexistent")
      {:error, :user_not_found, "User with alias 'nonexistent' not found"}
  """
  def swap(alias1, alias2) when is_binary(alias1) and is_binary(alias2) do
    Logger.info("=== Starting mobile number swap ===")
    Logger.info("User 1 alias: #{alias1}")
    Logger.info("User 2 alias: #{alias2}")

    with {:ok, user1} <- find_user_by_alias(alias1),
         {:ok, user2} <- find_user_by_alias(alias2),
         :ok <- validate_different_users(user1, user2),
         {:ok, result} <- perform_swap(user1, user2) do
      Logger.info("=== Mobile number swap completed successfully ===")
      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error("=== Mobile number swap failed: #{inspect(reason)} ===")
        error

      {:error, step, reason} = error ->
        Logger.error("=== Mobile number swap failed at #{step}: #{inspect(reason)} ===")
        error
    end
  end

  @doc """
  Diagnostic function to show current mobile numbers for two users.
  Does not perform any changes.

  ## Examples

      iex> diagnose("alice", "bob")
      :ok
  """
  def diagnose(alias1, alias2) when is_binary(alias1) and is_binary(alias2) do
    Logger.info("=== Mobile Number Swap Diagnosis ===")
    Logger.info("User 1 alias: #{alias1}")
    Logger.info("User 2 alias: #{alias2}")

    with {:ok, user1} <- find_user_by_alias(alias1),
         {:ok, user2} <- find_user_by_alias(alias2) do
      IO.puts("\n--- User 1: #{user1.alias} (ID: #{user1.id}) ---")
      display_mobile_info(user1)

      IO.puts("\n--- User 2: #{user2.alias} (ID: #{user2.id}) ---")
      display_mobile_info(user2)

      IO.puts("\n--- After Swap Preview ---")
      IO.puts("User 1 (#{user1.alias}) would get: #{format_mobile(user2.mobile_number)}")
      IO.puts("User 2 (#{user2.alias}) would get: #{format_mobile(user1.mobile_number)}")

      :ok
    else
      {:error, _reason} = error ->
        error

      {:error, _step, _reason} = error ->
        error
    end
  end

  # Private Functions

  defp find_user_by_alias(alias) do
    case Repo.one(from u in User, where: u.alias == ^alias) do
      nil ->
        {:error, :user_not_found, "User with alias '#{alias}' not found"}

      user ->
        Logger.info("Found user: #{user.alias} (ID: #{user.id})")
        {:ok, user}
    end
  end

  defp validate_different_users(user1, user2) do
    if user1.id == user2.id do
      {:error, :same_user, "Cannot swap mobile numbers for the same user"}
    else
      :ok
    end
  end

  defp perform_swap(user1, user2) do
    Logger.info("Starting transaction to swap mobile numbers...")
    decrypted1 = if user1.mobile_number_encrypted, do: user1.mobile_number_encrypted, else: nil
    decrypted2 = if user2.mobile_number_encrypted, do: user2.mobile_number_encrypted, else: nil
    Logger.info("User 1 (#{user1.alias}) current mobile: #{format_mobile(decrypted1)}")
    Logger.info("User 2 (#{user2.alias}) current mobile: #{format_mobile(decrypted2)}")

    Repo.transaction(fn ->
      # Store user2's mobile data temporarily
      temp_encrypted = user2.mobile_number_encrypted
      temp_hash = user2.mobile_number_hash
      temp_verified_at = user2.phone_verified_at

      # Update user2 with user1's mobile data
      user2_changeset =
        user2
        |> Ecto.Changeset.change(%{
          mobile_number_encrypted: user1.mobile_number_encrypted,
          mobile_number_hash: user1.mobile_number_hash,
          phone_verified_at: user1.phone_verified_at
        })

      case Repo.update(user2_changeset) do
        {:ok, updated_user2} ->
          decrypted_u2 =
            if updated_user2.mobile_number_encrypted,
              do: updated_user2.mobile_number_encrypted,
              else: nil

          Logger.info("Updated user 2 (#{user2.alias}) mobile to: #{format_mobile(decrypted_u2)}")

          # Update user1 with user2's mobile data (from temp storage)
          user1_changeset =
            user1
            |> Ecto.Changeset.change(%{
              mobile_number_encrypted: temp_encrypted,
              mobile_number_hash: temp_hash,
              phone_verified_at: temp_verified_at
            })

          case Repo.update(user1_changeset) do
            {:ok, updated_user1} ->
              decrypted_u1 =
                if updated_user1.mobile_number_encrypted,
                  do: updated_user1.mobile_number_encrypted,
                  else: nil

              Logger.info(
                "Updated user 1 (#{user1.alias}) mobile to: #{format_mobile(decrypted_u1)}"
              )

              Logger.info("Swap successful, committing transaction")

              %{
                user1: updated_user1,
                user2: updated_user2,
                summary: %{
                  user1_alias: updated_user1.alias,
                  user1_new_mobile: format_mobile(updated_user1.mobile_number),
                  user1_verified: !is_nil(updated_user1.phone_verified_at),
                  user2_alias: updated_user2.alias,
                  user2_new_mobile: format_mobile(updated_user2.mobile_number),
                  user2_verified: !is_nil(updated_user2.phone_verified_at)
                }
              }

            {:error, changeset} ->
              Logger.error("Failed to update user 1: #{inspect(changeset.errors)}")
              Repo.rollback({:error, :user1_update_failed, changeset.errors})
          end

        {:error, changeset} ->
          Logger.error("Failed to update user 2: #{inspect(changeset.errors)}")
          Repo.rollback({:error, :user2_update_failed, changeset.errors})
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, :transaction_failed, reason}
    end
  end

  defp display_mobile_info(user) do
    decrypted = if user.mobile_number_encrypted, do: user.mobile_number_encrypted, else: nil
    IO.puts("Mobile Number (encrypted): #{format_mobile(decrypted)}")
    IO.puts("Hash: #{format_binary(user.mobile_number_hash)}")

    IO.puts(
      "Verified: #{if user.phone_verified_at, do: "Yes (#{format_datetime(user.phone_verified_at)})", else: "No"}"
    )
  end

  defp format_mobile(nil), do: "<not set>"
  defp format_mobile(mobile), do: mobile

  defp format_binary(nil), do: "<not set>"

  defp format_binary(binary) when is_binary(binary) do
    "<#{byte_size(binary)} bytes>"
  end

  defp format_binary(_), do: "<invalid>"

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  @doc """
  Convenience function to verify the swap was successful.

  ## Examples

      iex> verify_swap("alice", "bob", "+15551234567", "+15559876543")
      :ok
  """
  def verify_swap(alias1, alias2, expected_mobile1, expected_mobile2)
      when is_binary(alias1) and is_binary(alias2) and is_binary(expected_mobile1) and
             is_binary(expected_mobile2) do
    with {:ok, user1} <- find_user_by_alias(alias1),
         {:ok, user2} <- find_user_by_alias(alias2) do
      results = [
        {user1.alias, user1.mobile_number, expected_mobile1},
        {user2.alias, user2.mobile_number, expected_mobile2}
      ]

      IO.puts("\n=== Verification Results ===")

      all_match? =
        Enum.all?(results, fn {alias, actual, expected} ->
          match? = actual == expected
          status = if match?, do: "✓", else: "✗"
          IO.puts("#{status} #{alias}: #{format_mobile(actual)} (expected: #{expected})")
          match?
        end)

      if all_match? do
        IO.puts("\n✓ All mobile numbers match expected values")
        :ok
      else
        IO.puts("\n✗ Some mobile numbers do not match")
        {:error, :verification_failed}
      end
    end
  end
end
