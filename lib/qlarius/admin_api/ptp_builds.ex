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

  @doc """
  Accepts a multipart build.

  `payload` is the whole request as one JSON object. A sibling `banner_image`
  file is the ad's banner. Form fields shaped like `trait_groups[0][title]`
  arrive as index-keyed maps and are turned into lists.
  """
  def prepare(params) when is_map(params) do
    params = nest_lists(params)

    case params["payload"] do
      payload when is_binary(payload) and payload != "" ->
        case Jason.decode(payload) do
          {:ok, body} when is_map(body) ->
            {:ok,
             body |> nest_lists() |> put_banner(params["banner_image"]) |> put_dry_run(params)}

          _ ->
            {:error, :invalid_payload}
        end

      _ ->
        {:ok, put_banner(params, params["banner_image"])}
    end
  end

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

  defp groups(base, marketer, list) when is_list(list) do
    list
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, [], []}, fn
      {attrs, index}, {:ok, groups, results} when is_map(attrs) ->
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

      _item, _acc ->
        {:halt, {:error, :invalid_trait_groups}}
    end)
  end

  defp groups(_base, _marketer, _other), do: {:error, :invalid_trait_groups}

  defp target(scope, base, marketer, groups, attrs) do
    ids = Enum.map(groups, &id_of/1)

    drop =
      attrs
      |> Map.get("drop_order", [])
      |> List.wrap()
      |> Enum.map(&at_group(ids, &1))
      |> Enum.reject(&is_nil/1)

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

  defp put_banner(body, %Plug.Upload{} = upload) do
    piece = if is_map(body["media_piece"]), do: body["media_piece"], else: %{}
    Map.put(body, "media_piece", Map.put(piece, "banner_image", upload))
  end

  defp put_banner(body, _upload), do: body

  defp put_dry_run(body, %{"dry_run" => dry_run}) when not is_map_key(body, "dry_run") do
    Map.put(body, "dry_run", dry_run)
  end

  defp put_dry_run(body, _params), do: body

  # Plug keeps `trait_groups[0][title]` as %{"0" => ...}` instead of a list.
  defp nest_lists(%_{} = struct), do: struct

  defp nest_lists(map) when is_map(map) do
    map = Map.new(map, fn {key, value} -> {key, nest_lists(value)} end)

    if index_keyed?(map) do
      map
      |> Enum.sort_by(fn {key, _} -> index_key(key) end)
      |> Enum.map(fn {_key, value} -> value end)
    else
      map
    end
  end

  defp nest_lists(list) when is_list(list), do: Enum.map(list, &nest_lists/1)
  defp nest_lists(other), do: other

  defp index_keyed?(map) do
    keys = Map.keys(map)
    keys != [] and Enum.all?(keys, &(index_key(&1) != nil))
  end

  defp index_key(key) when is_integer(key) and key >= 0, do: key

  defp index_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp index_key(_key), do: nil

  defp at_group(ids, index) do
    case integer(index) do
      n when is_integer(n) and n >= 0 -> Enum.at(ids, n)
      _ -> nil
    end
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_value), do: nil

  defp require_base(base) do
    cond do
      base in [nil, ""] -> {:error, :api_ref_required}
      ApiRef.valid?(base <> ".campaign") -> :ok
      true -> {:error, :invalid_api_ref}
    end
  end
end
