defmodule Qlarius.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Accounts.{Marketer, Scope, User, UserProxy, UserToken, UserLoginToken}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Wallets.LedgerHeader

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_with_me_file(id) do
    Repo.get(User, id)
    |> Repo.preload(:me_file)
  end

  def alias_available?(alias_value) when is_binary(alias_value) do
    query = from u in User, where: u.alias == ^alias_value

    case Repo.one(query) do
      nil -> true
      _ -> false
    end
  end

  def register_new_user(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.changeset(%User{}, attrs))
    |> Ecto.Multi.insert(:me_file, fn %{user: user} ->
      MeFile.changeset(%MeFile{}, %{
        user_id: user.id,
        date_of_birth: attrs[:date_of_birth],
        display_name: attrs[:alias]
      })
    end)
    |> Ecto.Multi.insert(:ledger_header, fn %{me_file: me_file} ->
      LedgerHeader.changeset(%LedgerHeader{}, %{
        me_file_id: me_file.id,
        description: "Wallet for #{attrs[:alias]}",
        balance: Decimal.new("0.00"),
        balance_payable: Decimal.new("0.00")
      })
    end)
    |> maybe_insert_proxy_user(attrs)
    |> maybe_insert_me_file_tags(attrs)
    |> Repo.transaction()
  end

  defp maybe_insert_proxy_user(multi, %{true_user_id: true_user_id})
       when not is_nil(true_user_id) do
    multi
    |> Ecto.Multi.insert(:proxy_user, fn %{user: user} ->
      UserProxy.changeset(%UserProxy{}, %{
        true_user_id: true_user_id,
        proxy_user_id: user.id,
        active: false
      })
    end)
  end

  defp maybe_insert_proxy_user(multi, _attrs), do: multi

  defp maybe_insert_me_file_tags(multi, attrs) do
    multi
    |> Ecto.Multi.run(:me_file_tags, fn _repo, %{user: user, me_file: me_file} ->
      tags = build_me_file_tags(me_file.id, user.id, attrs)
      {:ok, tags}
    end)
    |> Ecto.Multi.run(:insert_tags, fn repo, %{me_file_tags: tags} ->
      Enum.each(tags, fn tag_changeset ->
        repo.insert!(tag_changeset)
      end)

      {:ok, :inserted}
    end)
  end

  defp build_me_file_tags(me_file_id, user_id, attrs) do
    tags = []

    tags =
      if attrs[:sex_trait_id] do
        sex_trait = Qlarius.YouData.Traits.get_trait!(attrs[:sex_trait_id])

        [
          Qlarius.YouData.MeFiles.MeFileTag.changeset(%Qlarius.YouData.MeFiles.MeFileTag{}, %{
            me_file_id: me_file_id,
            trait_id: attrs[:sex_trait_id],
            tag_value: sex_trait.trait_name,
            added_by: user_id,
            modified_by: user_id
          })
          | tags
        ]
      else
        tags
      end

    tags =
      if attrs[:age_trait_id] do
        age_trait = Qlarius.YouData.Traits.get_trait!(attrs[:age_trait_id])

        [
          Qlarius.YouData.MeFiles.MeFileTag.changeset(%Qlarius.YouData.MeFiles.MeFileTag{}, %{
            me_file_id: me_file_id,
            trait_id: attrs[:age_trait_id],
            tag_value: age_trait.trait_name,
            added_by: user_id,
            modified_by: user_id
          })
          | tags
        ]
      else
        tags
      end

    tags =
      if attrs[:zip_code_trait_id] do
        zip_trait = Qlarius.YouData.Traits.get_trait!(attrs[:zip_code_trait_id])

        [
          Qlarius.YouData.MeFiles.MeFileTag.changeset(%Qlarius.YouData.MeFiles.MeFileTag{}, %{
            me_file_id: me_file_id,
            trait_id: attrs[:zip_code_trait_id],
            tag_value: zip_trait.trait_name,
            added_by: user_id,
            modified_by: user_id
          })
          | tags
        ]
      else
        tags
      end

    tags
  end

  def create_proxy_user(true_user_id, proxy_user_id) do
    %UserProxy{}
    |> UserProxy.changeset(%{
      true_user_id: true_user_id,
      proxy_user_id: proxy_user_id,
      active: false
    })
    |> Repo.insert()
  end

  def activate_proxy_user(true_user_id, proxy_user_id) do
    Repo.transaction(fn ->
      from(up in UserProxy, where: up.true_user_id == ^true_user_id)
      |> Repo.update_all(set: [active: false])

      from(up in UserProxy,
        where: up.true_user_id == ^true_user_id and up.proxy_user_id == ^proxy_user_id
      )
      |> Repo.update_all(set: [active: true])
    end)
  end

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
  # id parameter not used in TODO stub function
  def get_marketer!(%Scope{} = _scope, _id), do: raise("TODO")

  @doc """
  Creates a marketer.

  ## Examples

      iex> create_marketer(scope, %{field: value})
      {:ok, %Marketer{}}

      iex> create_marketer(scope, %{field: bad_value})
      {:error, ...}

  """
  # attrs parameter not used in TODO stub function
  def create_marketer(%Scope{} = _scope, _attrs \\ %{}) do
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
  # marketer and attrs parameters not used in TODO stub function
  def update_marketer(%Scope{} = _scope, %Marketer{} = _marketer, _attrs) do
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
  # marketer parameter not used in TODO stub function
  def delete_marketer(%Scope{} = _scope, %Marketer{} = _marketer) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking marketer changes.

  ## Examples

      iex> change_marketer(scope, marketer)
      %Todo{...}

  """
  # marketer parameter not used in TODO stub function
  def change_marketer(%Scope{} = _scope, %Marketer{} = _marketer, _attrs \\ %{}) do
    raise "TODO"
  end

  def get_user_by_phone_number(phone_number) do
    formatted_phone = format_phone_for_lookup(phone_number)
    hash = hash_phone_number(formatted_phone)
    Repo.get_by(User, mobile_number_hash: hash)
  end

  defp format_phone_for_lookup(phone) when is_binary(phone) do
    cond do
      String.starts_with?(phone, "+1") -> phone
      String.starts_with?(phone, "1") -> "+#{phone}"
      true -> "+1#{phone}"
    end
  end

  defp hash_phone_number(phone) do
    :crypto.hash(:sha256, phone)
  end

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def generate_user_remember_me_token(user) do
    {token, user_token} = UserToken.build_remember_me_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query) |> Repo.preload(me_file: :ledger_header)
  end

  def get_user_by_remember_me_token(token) do
    {:ok, query} = UserToken.verify_remember_me_token_query(token)
    Repo.one(query) |> Repo.preload(me_file: :ledger_header)
  end

  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  def delete_all_user_tokens(user) do
    Repo.delete_all(UserToken.by_user_and_contexts_query(user, :all))
  end

  def update_user_sign_in_tracking(user, attrs) do
    user
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
  end

  def generate_user_login_token(user_id) do
    login_token = UserLoginToken.build_login_token(user_id)
    Repo.insert!(login_token)
    login_token.token
  end

  def get_user_by_login_token(token) do
    query = UserLoginToken.verify_token_query(token)

    case Repo.one(query) do
      nil ->
        nil

      login_token ->
        login_token
        |> Ecto.Changeset.change(%{used: true})
        |> Repo.update!()

        get_user!(login_token.user_id)
    end
  end
end
