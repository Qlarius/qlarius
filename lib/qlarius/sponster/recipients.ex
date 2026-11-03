defmodule Qlarius.Sponster.Recipients do
  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Wallets

  def list_recipients do
    Repo.all(Recipient)
  end

  def list_for_creator(creator_id, opts \\ []) when is_integer(creator_id) do
    include_id = opts |> Keyword.get(:include) |> include_id()

    Recipient
    |> where([r], r.creator_id == ^creator_id and is_nil(r.archived_at))
    |> or_where([r], r.id == ^include_id)
    |> order_by([r], desc: r.is_primary, asc: r.name)
    |> Repo.all()
  end

  def primary_id(nil), do: nil

  def primary_id(creator_id) do
    Repo.one(
      from r in Recipient,
        where: r.creator_id == ^creator_id and r.is_primary == true and is_nil(r.archived_at),
        select: r.id,
        limit: 1
    )
  end

  def belongs_to_creator?(nil, _creator_id), do: false
  def belongs_to_creator?(_recipient_id, nil), do: false

  def belongs_to_creator?(recipient_id, creator_id) do
    Repo.exists?(
      from r in Recipient,
        where: r.id == ^recipient_id and r.creator_id == ^creator_id and is_nil(r.archived_at)
    )
  end

  @doc """
  Adds a publication under a creator. The first active recipient is primary.
  """
  def attach_to_creator(%Scope{} = scope, %Creator{} = creator, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    primary? = is_nil(primary_id(creator.id))
    name = attrs["name"]

    Repo.transaction(fn ->
      case create_recipient(%{
             "user_id" => scope.user.id,
             "approved_by_user_id" => scope.user.id,
             "approval_date" => now,
             "name" => name,
             "site_url" => attrs["site_url"],
             "message" => "Thank you for supporting #{name}.",
             "recipient_type_id" => attrs["recipient_type_id"] || 1,
             "target_amount" => "0.00",
             "split_code" => Ecto.UUID.generate(),
             "creator_id" => creator.id,
             "is_primary" => primary?
           }) do
        {:ok, recipient} ->
          if primary? do
            creator
            |> Ecto.Changeset.change(%{recipient_id: recipient.id})
            |> Repo.update!()
          end

          _ = Wallets.get_or_create_recipient_ledger_header(recipient)
          recipient

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp include_id(%{id: id}), do: id
  defp include_id(id) when is_integer(id), do: id
  defp include_id(_), do: -1

  def get_recipient!(id) do
    Repo.get!(Recipient, id)
  end

  def create_recipient(attrs \\ %{}) do
    attrs =
      Map.put_new(attrs, "referral_code", Qlarius.Referrals.generate_referral_code("recipient"))

    %Recipient{}
    |> Recipient.changeset(attrs)
    |> Repo.insert()
  end

  def update_recipient(%Recipient{} = recipient, attrs) do
    recipient
    |> Recipient.changeset(attrs)
    |> Repo.update()
  end

  def delete_recipient(%Recipient{} = recipient) do
    Repo.delete(recipient)
  end

  def change_recipient(%Recipient{} = recipient, attrs \\ %{}) do
    Recipient.changeset(recipient, attrs)
  end

  @doc """
  Copies an explicit sequence id onto create attrs. A blank value is left
  unset so the changeset can apply the current default.
  """
  def put_promo_sequence_id(attrs, params) when is_map(attrs) and is_map(params) do
    case Map.get(params, "promo_sequence_id") do
      id when id in [nil, ""] -> attrs
      id -> Map.put(attrs, "promo_sequence_id", id)
    end
  end
end
