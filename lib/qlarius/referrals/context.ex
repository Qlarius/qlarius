defmodule Qlarius.Referrals.Context do
  @moduledoc """
  Represents an inherent referral source captured at the moment an auth modal
  (or legacy `/register` page) opens.

  The struct is built once when the auth surface knows who or what "sent" the
  visitor — a creator's qlink page, an admin spawning a proxy user, or a raw
  `?ref=CODE` URL parameter — and then passed through the registration flow to
  `Qlarius.Accounts.register_new_user/2`.

  This lets us drop the referral-code text-entry step from the public
  registration UX (per plan §5.4) and still track the referral relationship in
  the database.

  ## Sources

  * `:creator` — visitor is on a creator's qlink page (or similar). The creator's
    own me_file `referral_code` is used; one is generated if absent.
  * `:admin` — a logged-in user is spawning a proxy user. The admin's me_file
    `referral_code` is used; one is generated if absent.
  * `:url` — an explicit `?ref=CODE` query-string parameter. No lookup is done
    here; the code is stored verbatim and resolved later by
    `Qlarius.Referrals.lookup_referrer_by_code/1`.

  A `nil` value (returned by `none/0`) means no referral context — registration
  can still proceed, just without creating a `referrals` row.
  """

  alias Qlarius.Accounts
  alias Qlarius.Accounts.User
  alias Qlarius.Referrals
  alias Qlarius.YouData.MeFiles.MeFile

  @type source :: :creator | :admin | :url
  @type t :: %__MODULE__{
          source: source(),
          code: String.t() | nil,
          source_user_id: integer() | nil
        }

  defstruct [:source, :code, :source_user_id]

  @doc """
  Build a referral context from a creator / qlink-page-owner user.

  Ensures the user's me_file has a `referral_code`, generating and persisting
  one if necessary. Returns `nil` if the user has no me_file at all (should be
  rare — registration always creates one).
  """
  @spec from_creator(User.t()) :: t() | nil
  def from_creator(%User{} = user), do: build_from_user(user, :creator)

  @doc """
  Build a referral context for an admin spawning a proxy user.

  Uses the admin's own me_file `referral_code` (generated if absent), mirroring
  the legacy behavior in `QlariusWeb.RegistrationLive.create_user/1`.
  """
  @spec from_admin(User.t()) :: t() | nil
  def from_admin(%User{} = user), do: build_from_user(user, :admin)

  @doc """
  Build a referral context from a raw `?ref=CODE` URL parameter.

  Trims the input and returns `nil` for empty / non-binary values. The code is
  stored verbatim — validity is checked later by
  `Qlarius.Referrals.lookup_referrer_by_code/1` when the multi inserts the
  `referrals` row.
  """
  @spec from_url(term()) :: t() | nil
  def from_url(code) when is_binary(code) do
    case String.trim(code) do
      "" -> nil
      trimmed -> %__MODULE__{source: :url, code: trimmed, source_user_id: nil}
    end
  end

  def from_url(_), do: nil

  @doc "Sentinel for no referral context."
  @spec none() :: nil
  def none, do: nil

  @doc """
  Returns the referral code string to pass to `Accounts.register_new_user/2`,
  or `nil` if the context is nil or has no resolvable code.
  """
  @spec code(t() | nil) :: String.t() | nil
  def code(nil), do: nil
  def code(%__MODULE__{code: code}), do: code

  @doc """
  Returns the source atom, or `nil` if the context is nil. Useful for logging
  and telemetry.
  """
  @spec source(t() | nil) :: source() | nil
  def source(nil), do: nil
  def source(%__MODULE__{source: source}), do: source

  # --- internal ---

  defp build_from_user(%User{id: user_id}, source) do
    case Accounts.get_me_file_by_user_id(user_id) do
      nil ->
        %__MODULE__{source: source, code: nil, source_user_id: user_id}

      me_file ->
        code = ensure_referral_code(me_file)
        %__MODULE__{source: source, code: code, source_user_id: user_id}
    end
  end

  defp ensure_referral_code(%MeFile{referral_code: code})
       when is_binary(code) and code != "",
       do: code

  defp ensure_referral_code(%MeFile{} = me_file) do
    new_code = Referrals.generate_referral_code("mefile")

    case Referrals.set_referral_code(me_file, new_code) do
      {:ok, _} -> new_code
      {:error, _} -> nil
    end
  end
end
