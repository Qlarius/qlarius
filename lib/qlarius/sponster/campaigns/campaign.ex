defmodule Qlarius.Sponster.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.Campaigns.{MediaSequence, Target, Bid}
  alias Qlarius.Wallets.LedgerHeader

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  @date_or_datetime_error "must be an ISO8601 date (YYYY-MM-DD) or datetime (YYYY-MM-DDThh:mm:ss[Z|±hh:mm])"

  schema "campaigns" do
    field :title, :string
    field :description, :string
    field :start_date, :naive_datetime
    field :end_date, :naive_datetime
    field :is_payable, :boolean
    field :is_throttled, :boolean
    field :is_ptp, :boolean, default: false
    field :api_ref, :string
    field :launched_at, :naive_datetime
    field :deactivated_at, :naive_datetime

    belongs_to :marketer, Marketer
    belongs_to :target, Target
    belongs_to :media_sequence, MediaSequence

    has_many :bids, Bid
    has_one :ledger_header, LedgerHeader

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :description,
      :is_payable,
      :is_throttled,
      :is_ptp,
      :api_ref,
      :launched_at,
      :deactivated_at
    ])
    |> cast_campaign_datetime(attrs, :start_date)
    |> cast_campaign_datetime(attrs, :end_date)
    |> validate_required([
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title
    ])
    |> validate_start_date_present()
    |> validate_end_date_on_or_after_start_date()
    |> apply_ptp_defaults(attrs)
    |> Qlarius.ApiRef.validate()
  end

  # PTP campaigns are Qadabra funded and spaced out by the global throttle, so
  # a new one defaults to non-payable and throttled unless the caller says otherwise.
  defp apply_ptp_defaults(%{data: %{id: nil}} = changeset, attrs) do
    if get_field(changeset, :is_ptp) do
      changeset
      |> default_unless_given(attrs, :is_payable, false)
      |> default_unless_given(attrs, :is_throttled, true)
    else
      changeset
    end
  end

  defp apply_ptp_defaults(changeset, _attrs), do: changeset

  defp default_unless_given(changeset, attrs, key, value) do
    if Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key)) do
      changeset
    else
      put_change(changeset, key, value)
    end
  end

  defp cast_campaign_datetime(changeset, attrs, field) when field in [:start_date, :end_date] do
    case fetch_attr(attrs, field) do
      :error ->
        changeset

      {:ok, value} ->
        case parse_campaign_datetime(value, field) do
          {:ok, %NaiveDateTime{} = dt} ->
            put_change(changeset, field, dt)

          {:ok, nil} ->
            put_change(changeset, field, nil)

          {:error, :invalid} ->
            add_error(changeset, field, @date_or_datetime_error)
        end
    end
  end

  defp validate_end_date_on_or_after_start_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    cond do
      is_nil(start_date) or is_nil(end_date) ->
        changeset

      NaiveDateTime.compare(end_date, start_date) in [:gt, :eq] ->
        changeset

      true ->
        add_error(changeset, :end_date, "must be on or after start_date")
    end
  end

  defp validate_start_date_present(changeset) do
    cond do
      not is_nil(get_field(changeset, :start_date)) ->
        changeset

      Keyword.has_key?(changeset.errors, :start_date) ->
        changeset

      true ->
        validate_required(changeset, [:start_date])
    end
  end

  defp fetch_attr(attrs, field) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, field) -> {:ok, Map.get(attrs, field)}
      Map.has_key?(attrs, Atom.to_string(field)) -> {:ok, Map.get(attrs, Atom.to_string(field))}
      true -> :error
    end
  end

  defp parse_campaign_datetime(value, _field) when value in [nil, ""], do: {:ok, nil}

  defp parse_campaign_datetime(%NaiveDateTime{} = dt, _field),
    do: {:ok, NaiveDateTime.truncate(dt, :second)}

  defp parse_campaign_datetime(%DateTime{} = dt, _field),
    do: {:ok, dt |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)}

  defp parse_campaign_datetime(%Date{} = date, field) do
    {:ok, date_to_naive(date, field)}
  end

  defp parse_campaign_datetime(value, field) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" ->
        {:ok, nil}

      true ->
        with {:error, _} <- DateTime.from_iso8601(value),
             {:error, _} <- NaiveDateTime.from_iso8601(value),
             {:error, _} <- Date.from_iso8601(value) do
          {:error, :invalid}
        else
          {:ok, %DateTime{} = dt, _offset} ->
            {:ok, dt |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)}

          {:ok, %NaiveDateTime{} = dt} ->
            {:ok, NaiveDateTime.truncate(dt, :second)}

          {:ok, %Date{} = date} ->
            {:ok, date_to_naive(date, field)}
        end
    end
  end

  defp parse_campaign_datetime(_value, _field), do: {:error, :invalid}

  defp date_to_naive(%Date{} = date, :start_date), do: NaiveDateTime.new!(date, ~T[00:00:00])
  defp date_to_naive(%Date{} = date, :end_date), do: NaiveDateTime.new!(date, ~T[23:59:59])
end
