defmodule Qlarius.AdminApi.Marketers do
  @moduledoc """
  Marketer reads and writes for the admin campaign API.

  Marketers created here have no user attached, send no email, and set up no
  billing. A real person is given access later through a `marketer_users`
  membership from the admin Marketer Manager page.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.Idempotent
  alias Qlarius.Accounts.{Marketer, MarketerUser, Marketers, Scope}
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaSequence, Target, TraitGroup}

  @fields ~w(business_name business_url contact_first_name contact_last_name contact_number contact_email sic_code)
  @default_limit 100
  @max_limit 500

  def fields, do: @fields

  def list(params) do
    from(m in Marketer, as: :marketer, order_by: [asc: m.business_name, asc: m.id])
    |> filter_q(params["q"])
    |> filter_domain(params["domain"])
    |> filter_api_ref_prefix(params["api_ref_prefix"])
    |> filter_has_ptp(params["has_ptp"])
    |> limit(^limit(params["limit"]))
    |> Repo.all()
    |> with_counts()
  end

  def fetch(id) do
    case Repo.get(Marketer, id) do
      nil -> {:error, :not_found}
      marketer -> {:ok, marketer |> List.wrap() |> with_counts() |> hd()}
    end
  end

  def create(%Scope{} = scope, params, opts) do
    attrs = Map.take(params, ["api_ref" | @fields])

    Idempotent.create(Marketer, params,
      fields: @fields,
      dry_run: opts[:dry_run],
      on_existing: params["on_existing"],
      preview: &preview/1,
      insert: fn _ -> Marketers.create_marketer(scope, attrs) end,
      update: &Marketers.update_marketer(scope, &1, &2)
    )
  end

  def update(%Scope{} = scope, %Marketer{} = marketer, params, opts) do
    attrs = Map.take(params, @fields)

    cond do
      api_ref_change?(marketer, params) ->
        {:error, :api_ref_immutable}

      opts[:dry_run] ->
        changeset = Marketer.changeset(marketer, attrs)

        if changeset.valid?,
          do:
            {:ok,
             %{
               result: "would_update",
               record: marketer,
               differences: Idempotent.differences(marketer, attrs, @fields)
             }},
          else: {:error, changeset}

      true ->
        differences = Idempotent.differences(marketer, attrs, @fields)

        with {:ok, updated} <- Marketers.update_marketer(scope, marketer, attrs) do
          {:ok, %{result: "updated", record: updated, differences: differences}}
        end
    end
  end

  def delete(%Scope{} = scope, %Marketer{} = marketer, opts) do
    dependents = dependents(marketer.id)

    cond do
      Enum.any?(dependents, fn {_key, count} -> count > 0 end) ->
        {:error, {:has_dependents, dependents}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{marketer: marketer.id}}}

      true ->
        with {:ok, _} <- Marketers.delete_marketer(scope, marketer) do
          {:ok, %{result: "deleted", removes: %{marketer: marketer.id}}}
        end
    end
  end

  def dependents(marketer_id) do
    %{
      campaigns: count(Campaign, marketer_id),
      media_pieces: count(MediaPiece, marketer_id),
      targets: count(Target, marketer_id),
      trait_groups: count(TraitGroup, marketer_id),
      media_sequences: count(MediaSequence, marketer_id),
      members: count(MarketerUser, marketer_id)
    }
  end

  defp preview(attrs) do
    changeset = Marketer.changeset(%Marketer{}, Map.take(attrs, ["api_ref" | @fields]))

    if changeset.valid?,
      do: {:ok, Ecto.Changeset.apply_changes(changeset)},
      else: {:error, changeset}
  end

  defp api_ref_change?(marketer, params) do
    Map.has_key?(params, "api_ref") and params["api_ref"] != marketer.api_ref
  end

  defp count(schema, marketer_id) do
    Repo.aggregate(from(r in schema, where: r.marketer_id == ^marketer_id), :count)
  end

  defp with_counts([]), do: []

  defp with_counts(marketers) do
    ids = Enum.map(marketers, & &1.id)

    counts =
      for {key, schema} <- [
            campaigns: Campaign,
            media_pieces: MediaPiece,
            targets: Target,
            trait_groups: TraitGroup,
            media_sequences: MediaSequence,
            members: MarketerUser
          ],
          into: %{} do
        {key, grouped_counts(schema, ids)}
      end

    ptp_counts =
      from(c in Campaign,
        where: c.marketer_id in ^ids and c.is_ptp == true,
        group_by: c.marketer_id,
        select: {c.marketer_id, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(marketers, fn marketer ->
      counts =
        counts
        |> Map.new(fn {key, by_id} -> {key, Map.get(by_id, marketer.id, 0)} end)
        |> Map.put(:ptp_campaigns, Map.get(ptp_counts, marketer.id, 0))

      Map.put(marketer, :counts, counts)
    end)
  end

  defp grouped_counts(schema, ids) do
    from(r in schema,
      where: r.marketer_id in ^ids,
      group_by: r.marketer_id,
      select: {r.marketer_id, count(r.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp filter_q(query, q) when is_binary(q) and q != "" do
    where(query, [m], ilike(m.business_name, ^"%#{escape_like(q)}%"))
  end

  defp filter_q(query, _), do: query

  defp filter_domain(query, domain) when is_binary(domain) and domain != "" do
    host = domain |> String.trim() |> String.downcase() |> strip_scheme()
    where(query, [m], ilike(m.business_url, ^"%#{escape_like(host)}%"))
  end

  defp filter_domain(query, _), do: query

  defp filter_api_ref_prefix(query, prefix) when is_binary(prefix) and prefix != "" do
    where(query, [m], like(m.api_ref, ^"#{escape_like(prefix)}%"))
  end

  defp filter_api_ref_prefix(query, _), do: query

  defp filter_has_ptp(query, value) when value in [true, "true", "1"] do
    where(
      query,
      [m],
      exists(
        from(c in Campaign,
          where: c.marketer_id == parent_as(:marketer).id and c.is_ptp == true
        )
      )
    )
  end

  defp filter_has_ptp(query, _), do: query

  defp strip_scheme(host) do
    host
    |> String.replace(~r{\Ahttps?://}, "")
    |> String.replace(~r{\Awww\.}, "")
    |> String.split("/", parts: 2)
    |> hd()
  end

  defp escape_like(value), do: String.replace(value, ~r/([\\%_])/, "\\\\\\1")

  defp limit(value) do
    case Integer.parse(to_string(value || "")) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end
end
