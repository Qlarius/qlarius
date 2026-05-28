defmodule Qlarius.Creators.RecipientProvisioning do
  @moduledoc """
  Ensures each tip-enabled Creator has a dedicated Sponster Recipient and ledger.
  """

  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.Creators.Creator
  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Wallets

  @doc """
  Returns the Creator's tipping Recipient, creating and linking one when missing.
  """
  def ensure_recipient_for_creator(%Creator{} = creator, opts \\ []) do
    creator = Repo.preload(creator, [:recipient, :users])
    site_url = Keyword.get(opts, :site_url)

    cond do
      match?(%Recipient{}, creator.recipient) ->
        ensure_ledger(creator.recipient)
        {:ok, creator.recipient}

      true ->
        with {:ok, recipient} <- create_recipient_for_creator(creator, site_url),
             {:ok, _updated} <- link_creator(creator, recipient) do
          ensure_ledger(recipient)
          {:ok, recipient}
        end
    end
  end

  @doc false
  def ensure_recipient_for_creator!(%Creator{} = creator) do
    case ensure_recipient_for_creator(creator) do
      {:ok, recipient} -> recipient
      {:error, reason} -> raise "could not provision recipient for creator #{creator.id}: #{inspect(reason)}"
    end
  end

  defp create_recipient_for_creator(%Creator{} = creator, site_url) do
    case provision_user_id(creator) do
      nil ->
        {:error, :no_owner_user}

      user_id ->
        Recipients.create_recipient(%{
          "user_id" => user_id,
          "name" => creator.name || "Creator",
          "description" => creator.bio,
          "message" =>
            "Thank you for supporting #{creator.name || "this creator"}. Your tips are greatly appreciated!",
          "site_url" => site_url || default_site_url(creator),
          "recipient_type_id" => 1,
          "target_amount" => Decimal.new("0"),
          "split_code" => Ecto.UUID.generate()
        })
    end
  end

  defp link_creator(%Creator{} = creator, %Recipient{} = recipient) do
    creator
    |> Ecto.Changeset.change(recipient_id: recipient.id)
    |> Repo.update()
  end

  defp ensure_ledger(%Recipient{} = recipient) do
    _ = Wallets.get_or_create_recipient_ledger_header(recipient)
    :ok
  end

  defp provision_user_id(%Creator{} = creator) do
    owner_user_id(creator) ||
      qlink_recipient_user_id(creator.id) ||
      platform_recipient_owner_user_id()
  end

  defp owner_user_id(%Creator{users: [user | _]}), do: user.id

  defp owner_user_id(%Creator{id: creator_id}) do
    from(cm in Qlarius.Creators.CreatorMembership,
      join: u in assoc(cm, :user),
      where: cm.creator_id == ^creator_id,
      order_by: [asc: cm.inserted_at],
      select: u.id,
      limit: 1
    )
    |> Repo.one()
  end

  defp qlink_recipient_user_id(creator_id) do
    from(p in QlinkPage,
      join: r in assoc(p, :recipient),
      where: p.creator_id == ^creator_id and not is_nil(p.recipient_id),
      select: r.user_id,
      limit: 1
    )
    |> Repo.one()
  end

  defp platform_recipient_owner_user_id do
    case Application.get_env(:qlarius, :recipient_provisioning_owner_user_id) do
      id when is_integer(id) -> id
      _ -> first_admin_user_id()
    end
  end

  defp first_admin_user_id do
    from(u in User,
      where: u.role == "admin",
      order_by: [asc: u.id],
      limit: 1,
      select: u.id
    )
    |> Repo.one()
  end

  defp default_site_url(%Creator{id: id}) do
    path = "/creators/#{id}"
    QlariusWeb.Endpoint.url() <> path
  end
end
