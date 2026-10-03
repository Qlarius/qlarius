defmodule Qlarius.AdminApi.PtpBuilds do
  @moduledoc """
  Builds one PTP campaign in a single transaction: marketer, ad, trait groups,
  target, sequence, and campaign. It never launches.

  A dry run performs the same writes inside a transaction and rolls them back,
  so a rerun with the same `api_ref_base` still finds nothing.
  """

  alias Qlarius.ApiRef
  alias Qlarius.Repo
  alias Qlarius.AdminApi.{Campaigns, Marketers, MediaPieces, MediaSequences, Targets, TraitGroups}

  def build(scope, params, opts) do
    with :ok <- require_base(params["api_ref_base"]) do
      Repo.transaction(fn ->
        case assemble(scope, params) do
          {:ok, result} ->
            if opts[:dry_run], do: Repo.rollback({:dry_run, result}), else: result

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)
      |> case do
        {:ok, result} ->
          {:ok, Map.put(result, :result, outcome(result.steps, false))}

        {:error, {:dry_run, result}} ->
          {:ok, Map.put(result, :result, outcome(result.steps, true))}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp assemble(scope, params) do
    base = params["api_ref_base"]

    with {:ok, marketer, marketer_result} <- marketer(scope, base, params["marketer"] || %{}),
         {:ok, piece, piece_result} <- piece(base, marketer, params["media_piece"] || %{}),
         {:ok, groups, group_results} <- groups(base, marketer, params["trait_groups"] || []),
         {:ok, target, target_result} <-
           target(scope, base, marketer, groups, params["target"] || %{}),
         {:ok, sequence, sequence_result} <-
           sequence(base, marketer, piece, params["sequence"] || %{}),
         {:ok, campaign, campaign_result} <-
           campaign(base, marketer, target, sequence, params["campaign"] || %{}) do
      {:ok,
       %{
         steps:
           [marketer_result, piece_result, target_result, sequence_result, campaign_result] ++
             group_results,
         api_refs: %{
           marketer: base <> ".marketer",
           ad: base <> ".ad",
           trait_groups:
             Enum.with_index(groups, 1) |> Enum.map(fn {_g, n} -> "#{base}.tg-#{n}" end),
           target: base <> ".target",
           sequence: base <> ".seq",
           campaign: base <> ".campaign"
         },
         marketer_id: id_of(marketer),
         media_piece_id: id_of(piece),
         trait_group_ids: Enum.map(groups, &id_of/1),
         target_id: id_of(target),
         media_sequence_id: id_of(sequence),
         campaign_id: id_of(campaign.record),
         bids: Map.get(campaign, :bids, [])
       }}
    end
  end

  defp marketer(scope, base, attrs) do
    attrs = Map.merge(attrs, %{"api_ref" => base <> ".marketer", "on_existing" => "skip"})

    case Marketers.create(scope, attrs, dry_run: false) do
      {:ok, %{record: record, result: result}} -> {:ok, record, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp piece(base, marketer, attrs) do
    attrs =
      Map.merge(attrs, %{
        "api_ref" => base <> ".ad",
        "marketer_id" => id_of(marketer),
        "on_existing" => "skip"
      })

    case MediaPieces.create(attrs, dry_run: false) do
      {:ok, %{record: record, result: result}} -> {:ok, record, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp groups(base, marketer, list) do
    list
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, [], []}, fn {attrs, index}, {:ok, groups, results} ->
      attrs =
        Map.merge(attrs, %{
          "api_ref" => "#{base}.tg-#{index}",
          "marketer_id" => id_of(marketer),
          "on_existing" => "skip"
        })

      case TraitGroups.create(attrs, dry_run: false) do
        {:ok, %{record: group, result: result}} ->
          {:cont, {:ok, groups ++ [group], results ++ [result]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp target(scope, base, marketer, groups, attrs) do
    ids = Enum.map(groups, &id_of/1)
    drop = Enum.map(attrs["drop_order"] || [], fn index -> Enum.at(ids, index) end)

    attrs = %{
      "api_ref" => base <> ".target",
      "marketer_id" => id_of(marketer),
      "title" => attrs["title"] || "PTP target",
      "bullseye" => ids,
      "drop_order" => Enum.reject(drop, &is_nil/1),
      "on_existing" => "skip"
    }

    case Targets.build(scope, attrs, dry_run: false) do
      {:ok, %{target: target, result: result}} -> {:ok, target, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sequence(base, marketer, piece, attrs) do
    attrs =
      Map.merge(attrs, %{
        "api_ref" => base <> ".seq",
        "marketer_id" => id_of(marketer),
        "media_piece_id" => id_of(piece),
        "on_existing" => "skip"
      })

    case MediaSequences.create(attrs, dry_run: false) do
      {:ok, %{record: sequence, result: result}} -> {:ok, sequence, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp campaign(base, marketer, target, sequence, attrs) do
    attrs =
      attrs
      |> Map.merge(%{
        "api_ref" => base <> ".campaign",
        "marketer_id" => id_of(marketer),
        "target_id" => id_of(target),
        "media_sequence_id" => id_of(sequence),
        "title" => attrs["title"] || "PTP campaign",
        "is_ptp" => true,
        "on_existing" => "skip"
      })
      |> Map.put_new("is_throttled", true)

    case Campaigns.create(attrs, dry_run: false) do
      {:ok, %{result: result} = campaign} -> {:ok, campaign, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp outcome(steps, dry_run) do
    cond do
      Enum.all?(steps, &(&1 == "matched")) -> "matched"
      dry_run -> "would_create"
      true -> "created"
    end
  end

  defp id_of(%{id: id}), do: id
  defp id_of(%{"id" => id}), do: id
  defp id_of(other), do: other

  defp require_base(base) do
    cond do
      base in [nil, ""] -> {:error, :api_ref_required}
      ApiRef.valid?(base <> ".campaign") -> :ok
      true -> {:error, :invalid_api_ref}
    end
  end
end
