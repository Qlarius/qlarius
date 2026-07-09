defmodule Qlarius.MeCP.OAuth.OAuthToken do
  @moduledoc """
  An access/refresh token pair bound to one grant. Refresh rotates the pair
  (old row revoked, new row minted), so a leaked refresh token dies on first
  legitimate use. Hashes only; plaintext never stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.OAuth.OAuthClient

  @type t :: %__MODULE__{}

  schema "mecp_oauth_tokens" do
    field :access_token_hash, :string
    field :refresh_token_hash, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :oauth_client, OAuthClient, foreign_key: :mecp_oauth_client_id
    belongs_to :grant, Grant, foreign_key: :mecp_grant_id

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :access_token_hash,
      :refresh_token_hash,
      :expires_at,
      :revoked_at,
      :mecp_oauth_client_id,
      :mecp_grant_id
    ])
    |> validate_required([:access_token_hash, :expires_at, :mecp_oauth_client_id, :mecp_grant_id])
    |> unique_constraint(:access_token_hash)
    |> unique_constraint(:refresh_token_hash)
  end
end
