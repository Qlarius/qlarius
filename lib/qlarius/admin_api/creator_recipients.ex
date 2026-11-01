defmodule Qlarius.AdminApi.CreatorRecipients do
  @moduledoc """
  Sister publications under a creator. Each has its own ledger, split code,
  tip jar, and Sponster bar. The creator keeps exactly one primary.
  """

  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.AdminApi.{Idempotent, Prices}
  alias Qlarius.Creators.Creator
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Sponster.Recipients
  alias Qlarius.Tiqit.Arcade.{Catalog, ImportHttp}
  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader

  @fields ~w(name description message site_url contact_email recipient_type_id)
  @locked ~w(user_id split_code approval_date approved_by_user_id)

  def list(%Creator{} = creator) do
    Repo.all(
      from r in Recipient,
        where: r.creator_id == ^creator.id,
        order_by: [desc: r.is_primary, asc: r.name]
    )
  end

  def fetch(%Creator{} = creator, id) do
    case Qlarius.AdminApi.Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(Recipient, id) do
          %Recipient{creator_id: creator_id} = recipient when creator_id == creator.id ->
            {:ok, recipient}

          _ ->
            {:error, :not_found}
        end
    end
  end

  def create(%Scope{} = scope, %Creator{} = creator, params, opts) do
    with :ok <- Prices.reject(params),
         :ok <- locked?(params),
         :ok <- site_url(params["site_url"]) do
      Idempotent.create(Recipient, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &(&1.creator_id == creator.id),
        preview: &preview(scope, creator, &1),
        insert: fn _ -> insert(scope, creator, params) end,
        update: fn recipient, _attrs -> save_fields(recipient, params) end
      )
    end
  end

  def update(%Scope{} = scope, %Creator{} = creator, %Recipient{} = recipient, params, opts) do
    with :ok <- owned(creator, recipient),
         :ok <- primary_change(recipient, params),
         {:ok, result} <-
           Qlarius.AdminApi.Recipients.update(scope, recipient, params, dry_run: opts[:dry_run]) do
      maybe_promote(creator, result, params, opts)
    end
  end

  def archive(%Creator{} = creator, %Recipient{} = recipient, opts) do
    with :ok <- owned(creator, recipient),
         :ok <- archive_allowed?(creator, recipient),
         :ok <- no_ledger_activity?(recipient) do
      if opts[:dry_run] do
        {:ok, %{result: "would_archive", record: recipient, differences: %{}}}
      else
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.transaction(fn ->
          recipient =
            recipient
            |> Ecto.Changeset.change(%{archived_at: now, is_primary: false})
            |> Repo.update!()

          if creator.recipient_id == recipient.id do
            creator |> Ecto.Changeset.change(%{recipient_id: nil}) |> Repo.update!()
          end

          recipient
        end)
        |> case do
          {:ok, recipient} -> {:ok, %{result: "archived", record: recipient, differences: %{}}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  def delete(%Creator{} = creator, %Recipient{} = recipient, opts) do
    with :ok <- owned(creator, recipient),
         :ok <- archive_allowed?(creator, recipient) do
      dependents = dependents(recipient)

      cond do
        Enum.any?(dependents, fn {_key, count} -> count > 0 end) ->
          {:error, {:has_dependents, dependents}}

        opts[:dry_run] ->
          {:ok, %{result: "would_delete", removes: %{recipient: recipient.id}}}

        true ->
          Repo.transaction(fn ->
            if creator.recipient_id == recipient.id do
              creator |> Ecto.Changeset.change(%{recipient_id: nil}) |> Repo.update!()
            end

            Repo.delete_all(from h in LedgerHeader, where: h.recipient_id == ^recipient.id)

            case Repo.delete(recipient) do
              {:ok, _} -> recipient.id
              {:error, %Ecto.Changeset{}} -> Repo.rollback({:has_dependents, dependents})
              {:error, reason} -> Repo.rollback(reason)
            end
          end)
          |> case do
            {:ok, id} -> {:ok, %{result: "deleted", removes: %{recipient: id}}}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  def promote(%Creator{} = creator, %Recipient{} = recipient) do
    with :ok <- owned(creator, recipient) do
      if recipient.archived_at do
        {:error, :primary_recipient}
      else
        Repo.transaction(fn ->
          Repo.update_all(
            from(r in Recipient,
              where:
                r.creator_id == ^creator.id and r.id != ^recipient.id and r.is_primary == true
            ),
            set: [is_primary: false]
          )

          recipient =
            recipient
            |> Ecto.Changeset.change(%{is_primary: true})
            |> Repo.update!()

          creator
          |> Ecto.Changeset.change(%{recipient_id: recipient.id})
          |> Repo.update!()

          recipient
        end)
      end
    end
  end

  defp preview(scope, creator, params) do
    changeset =
      Recipient.changeset(%Recipient{creator_id: creator.id}, %{
        "user_id" => scope.user.id,
        "name" => params["name"],
        "description" => params["description"],
        "message" => params["message"] || "Thank you for supporting #{params["name"]}.",
        "site_url" => params["site_url"],
        "contact_email" => params["contact_email"],
        "recipient_type_id" => params["recipient_type_id"] || 1,
        "split_code" => Ecto.UUID.generate(),
        "api_ref" => params["api_ref"],
        "target_amount" => "0.00",
        "is_primary" => is_nil(Recipients.primary_id(creator.id))
      })

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  defp insert(scope, creator, params) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    primary? = is_nil(Recipients.primary_id(creator.id))

    Repo.transaction(fn ->
      case %Recipient{}
           |> Recipient.changeset(%{
             "user_id" => scope.user.id,
             "approved_by_user_id" => scope.user.id,
             "approval_date" => now,
             "name" => params["name"],
             "description" => params["description"],
             "message" => params["message"] || "Thank you for supporting #{params["name"]}.",
             "site_url" => params["site_url"],
             "contact_email" => params["contact_email"],
             "recipient_type_id" => params["recipient_type_id"] || 1,
             "split_code" => Ecto.UUID.generate(),
             "referral_code" => Referrals.generate_referral_code("recipient"),
             "target_amount" => "0.00",
             "api_ref" => params["api_ref"],
             "creator_id" => creator.id,
             "is_primary" => primary?
           })
           |> Repo.insert() do
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

  defp save_fields(recipient, params) do
    recipient
    |> Recipient.changeset(Map.take(params, @fields))
    |> Repo.update()
  end

  defp maybe_promote(creator, %{result: result, record: recipient} = payload, params, opts) do
    cond do
      params["is_primary"] not in [true, "true", "1"] ->
        {:ok, payload}

      opts[:dry_run] or result == "would_update" ->
        differences = Map.put(payload.differences, "is_primary", true)
        {:ok, %{payload | differences: differences}}

      recipient.is_primary ->
        {:ok, payload}

      true ->
        case promote(creator, recipient) do
          {:ok, recipient} -> {:ok, %{payload | record: recipient}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp primary_change(recipient, params) do
    if params["is_primary"] in [false, "false", "0"] and recipient.is_primary do
      {:error, :primary_recipient}
    else
      :ok
    end
  end

  defp no_ledger_activity?(recipient) do
    case dependents(recipient).ledger_entries do
      0 -> :ok
      count -> {:error, {:has_dependents, %{ledger_entries: count}}}
    end
  end

  defp archive_allowed?(creator, recipient) do
    siblings =
      Repo.exists?(
        from r in Recipient,
          where: r.creator_id == ^creator.id and r.id != ^recipient.id and is_nil(r.archived_at)
      )

    if recipient.is_primary and siblings do
      {:error, :primary_recipient}
    else
      :ok
    end
  end

  defp owned(creator, recipient) do
    if recipient.creator_id == creator.id, do: :ok, else: {:error, :not_found}
  end

  defp dependents(recipient) do
    %{
      ledger_entries:
        Repo.aggregate(
          from(e in LedgerEntry,
            join: h in assoc(e, :ledger_header),
            where: h.recipient_id == ^recipient.id
          ),
          :count
        ),
      catalogs: Repo.aggregate(from(c in Catalog, where: c.recipient_id == ^recipient.id), :count)
    }
  end

  defp locked?(params) do
    case Enum.find(@locked, &Map.has_key?(params, &1)) do
      nil -> :ok
      field -> {:error, {:field_not_writable, field}}
    end
  end

  defp site_url(url) when is_binary(url) and url != "" do
    if ImportHttp.public_url?(url, ["http", "https"]),
      do: :ok,
      else: {:error, "site_url must be an http(s) URL"}
  end

  defp site_url(_), do: {:error, "site_url is required"}
end
