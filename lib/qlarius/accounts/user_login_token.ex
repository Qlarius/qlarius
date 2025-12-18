defmodule Qlarius.Accounts.UserLoginToken do
  @moduledoc """
  One-time tokens for auto-login after registration/verification.
  These tokens expire after 1 minute or after being used once.
  """
  use Ecto.Schema
  import Ecto.Query

  schema "user_login_tokens" do
    field :token, :string
    field :user_id, :integer
    field :expires_at, :utc_datetime
    field :used, :boolean, default: false

    timestamps(updated_at: false)
  end

  def build_login_token(user_id) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    expires_at = DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.truncate(:second)

    %__MODULE__{
      token: token,
      user_id: user_id,
      expires_at: expires_at,
      used: false
    }
  end

  def verify_token_query(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from t in __MODULE__,
      where: t.token == ^token and t.used == false and t.expires_at > ^now
  end
end
