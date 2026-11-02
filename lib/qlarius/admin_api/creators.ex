defmodule Qlarius.AdminApi.Creators do
  @moduledoc """
  Admin API creators. A create also links one approved recipient. It does
  not add a membership and it does not call recipient provisioning.
  """

  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.AdminApi.{Idempotent, Params, Prices, RemoteImage}
  alias Qlarius.Creators.Creator
  alias Qlarius.Qlink.Urls
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Tiqit.Arcade.{Catalog, ImportHttp}
  alias Qlarius.Wallets
  alias QlariusWeb.Uploaders.RecipientBrandImage

  @fields ~w(name bio)
  @recipient_fields ~w(name description message site_url contact_email recipient_type_id)
  @locked ~w(user_id split_code approval_date approved_by_user_id)

  def list(params) do
    Creator
    |> filter_q(blank(params["q"]))
    |> filter_prefix(blank(params["api_ref_prefix"]))
    |> order_by([c], asc: c.name)
    |> maybe_limit(Params.limit(params, nil))
    |> preload([
      :recipient,
      recipients: ^from(r in Recipient, order_by: [desc: r.is_primary, asc: r.name]),
      catalogs: ^from(cat in Catalog, order_by: [asc: cat.name])
    ])
    |> Repo.all()
  end

  def fetch(id) do
    case Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(Creator, id) do
          nil ->
            {:error, :not_found}

          creator ->
            {:ok,
             Repo.preload(creator, [
               :recipient,
               :recipients,
               catalogs: from(c in Catalog, order_by: [asc: c.name])
             ])}
        end
    end
  end

  def create(%Scope{} = scope, params, opts) do
    with :ok <- Prices.reject(params),
         :ok <- locked?(params),
         :ok <- recipient_api_ref_available?(params) do
      Idempotent.create(Creator, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        extra_differences: &recipient_differences(&1, params["recipient"] || %{}),
        preview: &preview(scope, &1),
        insert: fn _ -> insert(scope, params) end,
        update: fn creator, _attrs -> update_records(scope, creator, params) end
      )
    end
  end

  def update(%Scope{} = scope, %Creator{} = creator, params, opts) do
    creator = Repo.preload(creator, :recipient)

    with :ok <- Prices.reject(params),
         :ok <- immutable?(creator, params),
         :ok <- locked?(params),
         :ok <- RemoteImage.validate(params["image_url"]) do
      differences =
        creator
        |> Idempotent.differences(params, @fields)
        |> Map.merge(recipient_differences(creator, params["recipient"] || %{}))
        |> Map.merge(RemoteImage.difference(creator, params))

      if opts[:dry_run] do
        preview_update(creator, params, differences)
      else
        with {:ok, updated} <- update_records(scope, creator, params) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
      end
    end
  end

  defp preview(scope, params) do
    changeset =
      %Creator{}
      |> Creator.changeset(Map.take(params, ["api_ref" | @fields]))

    recipient = params["recipient"] || %{}
    recipient_changeset = recipient_changeset(scope, nil, recipient, params["name"])

    with true <- changeset.valid? || {:error, changeset},
         true <- recipient_changeset.valid? || {:error, recipient_changeset},
         :ok <- RemoteImage.validate(params["image_url"]),
         :ok <- RemoteImage.validate(recipient["graphic_url"]),
         :ok <- site_url(recipient["site_url"]) do
      creator = Ecto.Changeset.apply_changes(changeset)
      {:ok, %{creator | recipient: Ecto.Changeset.apply_changes(recipient_changeset)}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp preview_update(creator, params, differences) do
    changeset = Creator.changeset(creator, Map.take(params, @fields))

    if changeset.valid? do
      {:ok,
       %{
         result: "would_update",
         record: Ecto.Changeset.apply_changes(changeset),
         differences: differences
       }}
    else
      {:error, changeset}
    end
  end

  defp insert(scope, params) do
    Repo.transaction(fn ->
      with {:ok, creator} <- insert_creator(params),
           {:ok, recipient} <- insert_recipient(scope, creator, params["recipient"] || %{}),
           {:ok, creator} <- link_recipient(creator, recipient),
           {:ok, creator} <- maybe_creator_image(creator, params["image_url"]),
           {:ok, recipient} <-
             maybe_graphic(creator.recipient, (params["recipient"] || %{})["graphic_url"]) do
        Wallets.get_or_create_recipient_ledger_header(recipient)
        %{creator | recipient: recipient}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_creator(params) do
    %Creator{}
    |> Creator.changeset(Map.take(params, ["api_ref" | @fields]))
    |> Repo.insert()
  end

  defp insert_recipient(scope, creator, recipient_params) do
    scope
    |> recipient_changeset(creator, recipient_params, creator.name)
    |> Repo.insert()
  end

  defp recipient_changeset(scope, creator, recipient_params, fallback_name) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    name = recipient_params["name"] || fallback_name

    attrs = %{
      "user_id" => scope.user.id,
      "approved_by_user_id" => scope.user.id,
      "approval_date" => now,
      "name" => name,
      "description" => recipient_params["description"],
      "message" => recipient_params["message"] || "Thank you for supporting #{name}.",
      "site_url" => recipient_site_url(recipient_params, creator),
      "contact_email" => recipient_params["contact_email"],
      "recipient_type_id" => recipient_params["recipient_type_id"] || 1,
      "split_code" => Ecto.UUID.generate(),
      "referral_code" => Referrals.generate_referral_code("recipient"),
      "target_amount" => "0.00",
      "api_ref" => recipient_params["api_ref"],
      "is_primary" => true
    }

    attrs =
      case creator do
        %Creator{id: id} when is_integer(id) -> Map.put(attrs, "creator_id", id)
        _ -> attrs
      end

    Recipient.changeset(%Recipient{}, attrs)
  end

  defp recipient_site_url(%{"site_url" => url}, _creator) when is_binary(url) and url != "",
    do: url

  defp recipient_site_url(_params, %Creator{id: id}) when is_integer(id) do
    Urls.public_app_url("/creators/#{id}")
  end

  defp recipient_site_url(_params, _), do: "https://example.com"

  defp recipient_api_ref_available?(params) do
    case get_in(params, ["recipient", "api_ref"]) do
      ref when ref in [nil, ""] ->
        :ok

      ref ->
        case Repo.get_by(Recipient, api_ref: ref) do
          nil ->
            :ok

          recipient ->
            case Repo.get_by(Creator, api_ref: params["api_ref"]) do
              %Creator{} = creator ->
                if recipient.creator_id == creator.id or creator.recipient_id == recipient.id do
                  :ok
                else
                  {:error, {:recipient_api_ref_conflict, ref}}
                end

              _ ->
                {:error, {:recipient_api_ref_conflict, ref}}
            end
        end
    end
  end

  defp link_recipient(creator, recipient) do
    with {:ok, recipient} <-
           recipient
           |> Ecto.Changeset.change(%{creator_id: creator.id, is_primary: true})
           |> Repo.update() do
      creator
      |> Ecto.Changeset.change(%{recipient_id: recipient.id})
      |> Repo.update()
      |> case do
        {:ok, creator} -> {:ok, %{creator | recipient: recipient}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp update_records(_scope, creator, params) do
    creator = Repo.preload(creator, :recipient)

    Repo.transaction(fn ->
      with {:ok, creator} <- save_creator(creator, params),
           {:ok, recipient} <- save_recipient(creator.recipient, params["recipient"] || %{}),
           {:ok, creator} <- maybe_creator_image(creator, params["image_url"]),
           {:ok, recipient} <-
             maybe_graphic(recipient, (params["recipient"] || %{})["graphic_url"]) do
        %{creator | recipient: recipient}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp save_creator(creator, params) do
    creator
    |> Creator.changeset(Map.take(params, @fields))
    |> Repo.update()
  end

  defp save_recipient(nil, params) when map_size(params) == 0, do: {:ok, nil}

  defp save_recipient(nil, _params), do: {:error, :recipient_required}

  defp save_recipient(recipient, params) when map_size(params) == 0, do: {:ok, recipient}

  defp save_recipient(recipient, params) do
    recipient
    |> Recipient.changeset(Map.take(params, @recipient_fields))
    |> Repo.update()
  end

  defp maybe_creator_image(creator, url) when is_binary(url) and url != "" do
    RemoteImage.assign(creator, url, "creator-#{creator.id}")
  end

  defp maybe_creator_image(creator, _), do: {:ok, creator}

  defp maybe_graphic(nil, _), do: {:ok, nil}

  defp maybe_graphic(recipient, url) when is_binary(url) and url != "" do
    RemoteImage.assign(recipient, url, "recipient-#{recipient.id}",
      field: :graphic_url,
      uploader: RecipientBrandImage
    )
  end

  defp maybe_graphic(recipient, _), do: {:ok, recipient}

  defp recipient_differences(%Creator{} = creator, params) do
    creator = Repo.preload(creator, :recipient)
    recipient_differences(creator.recipient, params)
  end

  defp recipient_differences(nil, params) when map_size(params) == 0, do: %{}

  defp recipient_differences(nil, _params),
    do: %{"recipient" => %{"current" => nil, "requested" => "present"}}

  defp recipient_differences(%Recipient{} = recipient, params) do
    params =
      if Map.has_key?(params, "recipient_type_id") do
        Map.put(params, "recipient_type_id", type_id(params["recipient_type_id"]))
      else
        params
      end

    recipient
    |> Idempotent.differences(params, @recipient_fields)
    |> Map.new(fn {key, value} -> {"recipient.#{key}", value} end)
  end

  defp type_id(nil), do: nil
  defp type_id(value), do: Params.integer(value) || value

  defp locked?(params) do
    recipient = params["recipient"] || %{}

    case Enum.find(@locked, &(Map.has_key?(params, &1) or Map.has_key?(recipient, &1))) do
      nil -> :ok
      field -> {:error, {:field_not_writable, field}}
    end
  end

  defp immutable?(creator, params) do
    if Map.has_key?(params, "api_ref") and params["api_ref"] != creator.api_ref do
      {:error, :api_ref_immutable}
    else
      :ok
    end
  end

  defp site_url(nil), do: :ok
  defp site_url(""), do: :ok

  defp site_url(url) do
    if ImportHttp.public_url?(url, ["http", "https"]),
      do: :ok,
      else: {:error, "site_url must be an http(s) URL"}
  end

  defp filter_q(query, nil), do: query

  defp filter_q(query, q) do
    like = "%#{escape_like(q)}%"
    where(query, [c], ilike(c.name, ^like) or ilike(c.api_ref, ^like))
  end

  defp filter_prefix(query, nil), do: query

  defp filter_prefix(query, prefix) do
    where(query, [c], ilike(c.api_ref, ^"#{escape_like(prefix)}%"))
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank(_), do: nil

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
