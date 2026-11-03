defmodule Qlarius.AdminApi.Recipients do
  @moduledoc """
  Recipients created on their own, with no creator attached. The token's
  admin user owns the row. `split_code` is generated and never writable.
  """

  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.AdminApi.{Idempotent, Params, Prices, RemoteImage}
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Sponster.PromoSequence
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Wallets
  alias QlariusWeb.Uploaders.RecipientBrandImage

  @fields ~w(name description message site_url contact_email recipient_type_id promo_sequence_id)
  @locked ~w(user_id split_code approval_date approved_by_user_id)

  def list(params) do
    Recipient
    |> filter_type(Params.integer(params["recipient_type_id"]))
    |> filter_q(blank(params["q"]))
    |> filter_prefix(blank(params["api_ref_prefix"]))
    |> order_by([r], asc: r.name)
    |> limit(^Params.limit(params, 100))
    |> Repo.all()
  end

  def fetch(id) do
    case Params.integer(id) do
      nil ->
        {:error, :not_found}

      id ->
        case Repo.get(Recipient, id) do
          nil -> {:error, :not_found}
          recipient -> {:ok, recipient}
        end
    end
  end

  def create(%Scope{} = scope, params, opts) do
    with {:ok, params} <- sequence_param(params),
         :ok <- Prices.reject(params),
         :ok <- locked?(params) do
      Idempotent.create(Recipient, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        preview: &preview(scope, &1),
        insert: fn _ -> insert(scope, params) end,
        update: fn recipient, _attrs -> save(recipient, params) end
      )
    end
  end

  def update(%Scope{} = _scope, %Recipient{} = recipient, params, opts) do
    with {:ok, params} <- sequence_param(params),
         :ok <- Prices.reject(params),
         :ok <- immutable?(recipient, params),
         :ok <- locked?(params) do
      attrs = Map.take(params, @fields)
      differences = Idempotent.differences(recipient, stringify_type(params), @fields)

      if opts[:dry_run] do
        changeset = Recipient.changeset(recipient, attrs)

        if changeset.valid? do
          {:ok, %{result: "would_update", record: recipient, differences: differences}}
        else
          {:error, changeset}
        end
      else
        with {:ok, updated} <- save(recipient, params) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
      end
    end
  end

  defp preview(scope, params) do
    changeset = Recipient.changeset(%Recipient{}, preview_attrs(scope, params))

    with true <- changeset.valid? || {:error, changeset},
         :ok <- RemoteImage.validate(params["graphic_url"]) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert(scope, params) do
    Repo.transaction(fn ->
      with {:ok, recipient} <- save_new(scope, params),
           {:ok, recipient} <- maybe_graphic(recipient, params["graphic_url"]) do
        Wallets.get_or_create_recipient_ledger_header(recipient)
        recipient
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp save_new(scope, params) do
    %Recipient{}
    |> Recipient.changeset(preview_attrs(scope, params))
    |> Repo.insert()
  end

  defp save(recipient, params) do
    Repo.transaction(fn ->
      with {:ok, recipient} <-
             recipient |> Recipient.changeset(Map.take(params, @fields)) |> Repo.update(),
           {:ok, recipient} <- maybe_graphic(recipient, params["graphic_url"]) do
        recipient
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp preview_attrs(scope, params) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %{
      "user_id" => scope.user.id,
      "approved_by_user_id" => scope.user.id,
      "approval_date" => now,
      "name" => params["name"],
      "description" => params["description"],
      "message" => params["message"] || "Thank you for your support.",
      "site_url" => params["site_url"],
      "contact_email" => params["contact_email"],
      "recipient_type_id" => params["recipient_type_id"] || 1,
      "split_code" => Ecto.UUID.generate(),
      "referral_code" => Referrals.generate_referral_code("recipient"),
      "target_amount" => "0.00",
      "api_ref" => params["api_ref"]
    }
    |> Qlarius.Sponster.Recipients.put_promo_sequence_id(params)
  end

  defp maybe_graphic(recipient, url) when is_binary(url) and url != "" do
    RemoteImage.assign(recipient, url, "recipient-#{recipient.id}",
      field: :graphic_url,
      uploader: RecipientBrandImage
    )
  end

  defp maybe_graphic(recipient, _), do: {:ok, recipient}

  defp sequence_param(params) do
    if Map.has_key?(params, "promo_sequence_id") do
      case params["promo_sequence_id"] do
        value when value in [nil, ""] ->
          {:ok, Map.put(params, "promo_sequence_id", nil)}

        value ->
          case Params.integer(value) do
            nil ->
              {:error, :promo_sequence_not_found}

            id ->
              if Repo.exists?(from s in PromoSequence, where: s.id == ^id) do
                {:ok, Map.put(params, "promo_sequence_id", id)}
              else
                {:error, :promo_sequence_not_found}
              end
          end
      end
    else
      {:ok, params}
    end
  end

  defp stringify_type(params) do
    case Params.integer(params["recipient_type_id"]) do
      nil -> params
      id -> Map.put(params, "recipient_type_id", id)
    end
  end

  defp locked?(params) do
    case Enum.find(@locked, &Map.has_key?(params, &1)) do
      nil -> :ok
      field -> {:error, {:field_not_writable, field}}
    end
  end

  defp immutable?(recipient, params) do
    if Map.has_key?(params, "api_ref") and params["api_ref"] != recipient.api_ref do
      {:error, :api_ref_immutable}
    else
      :ok
    end
  end

  defp filter_type(query, nil), do: query
  defp filter_type(query, type_id), do: where(query, [r], r.recipient_type_id == ^type_id)

  defp filter_q(query, nil), do: query

  defp filter_q(query, q) do
    like = "%#{escape_like(q)}%"
    where(query, [r], ilike(r.name, ^like) or ilike(r.api_ref, ^like))
  end

  defp filter_prefix(query, nil), do: query

  defp filter_prefix(query, prefix) do
    where(query, [r], ilike(r.api_ref, ^"#{escape_like(prefix)}%"))
  end

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
