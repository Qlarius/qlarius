defmodule Qlarius.MeCP.OAuth.OAuthCode do
  @moduledoc """
  A single-use PKCE authorization code, minted when the user approves a
  connector and bound to the grant that approval created. Short-lived
  (minutes); consumed exactly once at the token endpoint.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.MeCP.OAuth.OAuthClient

  @type t :: %__MODULE__{}

  schema "mecp_oauth_codes" do
    field :code_hash, :string
    field :redirect_uri, :string
    field :code_challenge, :string
    field :code_challenge_method, :string, default: "S256"
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :oauth_client, OAuthClient, foreign_key: :mecp_oauth_client_id
    belongs_to :grant, Grant, foreign_key: :mecp_grant_id

    timestamps(type: :utc_datetime)
  end

  def changeset(code, attrs) do
    code
    |> cast(attrs, [
      :code_hash,
      :redirect_uri,
      :code_challenge,
      :code_challenge_method,
      :expires_at,
      :used_at,
      :mecp_oauth_client_id,
      :mecp_grant_id
    ])
    |> validate_required([
      :code_hash,
      :redirect_uri,
      :code_challenge,
      :code_challenge_method,
      :expires_at,
      :mecp_oauth_client_id,
      :mecp_grant_id
    ])
    |> validate_inclusion(:code_challenge_method, ["S256"])
    |> unique_constraint(:code_hash)
  end
end
