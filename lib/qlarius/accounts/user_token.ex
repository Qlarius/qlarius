defmodule Qlarius.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias Qlarius.Accounts.UserToken

  @rand_size 32

  @session_validity_in_days 10
  @remember_me_validity_in_days 60

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, Qlarius.Accounts.User

    timestamps(updated_at: false)
  end

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: "session", user_id: user.id}}
  end

  def build_remember_me_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: "remember_me", user_id: user.id}}
  end

  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  def verify_remember_me_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "remember_me"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@remember_me_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  def by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  def by_user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
