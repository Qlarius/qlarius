defmodule Qlarius.AdminApi.Targets do
  @moduledoc """
  Assembles marketer or creator targets from trait groups that already exist.

  Bands are built bullseye outward. Each id in `drop_order` adds the next band
  without that group, which is the shape bids and population both expect.
  """

  import Ecto.Query

  alias Qlarius.ApiRef
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    Target,
    TargetBand,
    TargetBandTraitGroup,
    Targets,
    TraitGroup
  }

  def list(params) do
    from(t in Target, order_by: [desc: t.id])
    |> filter_owner(params)
    |> filter_archived(params["archived"])
    |> filter_prefix(params["api_ref_prefix"])
    |> limit(100)
    |> Repo.all()
  end

  def fetch(id) do
    case Repo.get(Target, id) do
      nil -> {:error, :not_found}
      target -> {:ok, present(target)}
    end
  end

  def build(scope, params, opts) do
    with :ok <- require_ref(params["api_ref"]),
         {:ok, owner} <- owner(params),
         {:ok, groups} <- load_groups(params["bullseye"], owner),
         {:ok, planned} <- plan(groups, params["drop_order"] || []) do
      bands = Enum.map(planned, &band_plan/1)
      existing = Repo.get_by(Target, api_ref: params["api_ref"])

      cond do
        opts[:dry_run] && is_nil(existing) ->
          {:ok, %{result: "would_create", bands: bands, target: nil}}

        opts[:dry_run] && same_owner?(existing, owner) ->
          {:ok, %{result: "would_update", bands: bands, target: present(existing)}}

        existing && !same_owner?(existing, owner) ->
          {:error, {:api_ref_conflict, params["api_ref"]}}

        existing && params["on_existing"] != "update" ->
          {:ok,
           %{
             result: "matched",
             matched: true,
             bands: current_bands(existing),
             target: present(existing)
           }}

        existing ->
          rebuild(existing, planned, params)

        true ->
          create(scope, owner, planned, params)
      end
    end
  end

  def add_band(target, trait_group_id) do
    with :ok <- editable(target) do
      Targets.create_outer_band(target.id, int(trait_group_id))
    end
  end

  def delete_outermost(target) do
    with :ok <- editable(target) do
      Targets.delete_outermost_band(target.id)
    end
  end

  def clone(scope, target, params) do
    with :ok <- require_ref(params["api_ref"]) do
      dest = dest_owner(params, target)

      if dest == owner_of(target) do
        copy_structure(target, dest, params)
      else
        case Targets.clone_across_orgs(scope, target, dest,
               title: params["title"] || target.title
             ) do
          {:ok, clone} ->
            with {:ok, clone} <- Targets.update_target(clone, %{"api_ref" => params["api_ref"]}) do
              {:ok, present(clone)}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  def populate(target), do: Targets.trigger_population(target)

  def population(target) do
    counts = Targets.get_band_population_counts(target.id)
    bands = Targets.get_bands_for_target(target.id)

    %{
      population_status: target.population_status,
      last_populated_at: target.last_populated_at,
      bands:
        Enum.map(bands, fn band ->
          %{
            id: band.id,
            label: Targets.band_label(band, bands),
            count: Map.get(counts, band.id, 0)
          }
        end)
    }
  end

  def delete(target, opts) do
    cond do
      Targets.used_in_campaign?(target.id) ->
        {:error, {:has_dependents, %{campaigns: 1}}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{target: target.id}}}

      true ->
        with {:ok, _} <- Targets.delete_target(target) do
          {:ok, %{result: "deleted", removes: %{target: target.id}}}
        end
    end
  end

  defp create(_scope, owner, planned, params) do
    attrs =
      %{
        "title" => params["title"],
        "description" => params["description"],
        "api_ref" => params["api_ref"]
      }
      |> Map.merge(owner_attrs(owner))

    with {:ok, target} <- Targets.create_target(attrs),
         :ok <- write_bands(target, planned) do
      {:ok, %{result: "created", target: present(target), bands: Enum.map(planned, &band_plan/1)}}
    end
  end

  defp rebuild(target, planned, params) do
    with :ok <- editable(target),
         {:ok, target} <-
           Targets.update_target(target, Map.take(params, ["title", "description"])),
         :ok <- clear_bands(target),
         :ok <- write_bands(target, planned) do
      {:ok, %{result: "updated", target: present(target), bands: Enum.map(planned, &band_plan/1)}}
    end
  end

  defp write_bands(target, [bullseye | rest]) do
    with {:ok, band} <- Targets.create_bullseye_band(target.id),
         :ok <- attach(band.id, bullseye),
         :ok <- drop_rest(target.id, rest, bullseye) do
      :ok
    end
  end

  defp drop_rest(_target_id, [], _previous), do: :ok

  defp drop_rest(target_id, [band | rest], previous) do
    dropped = Enum.map(previous, & &1.id) -- Enum.map(band, & &1.id)

    case dropped do
      [trait_group_id] ->
        with {:ok, _} <- Targets.create_outer_band(target_id, trait_group_id) do
          drop_rest(target_id, rest, band)
        end

      _ ->
        {:error, :band_drop_mismatch}
    end
  end

  defp attach(band_id, groups) do
    Enum.reduce_while(groups, :ok, fn group, :ok ->
      case Targets.add_trait_group_to_band(band_id, group.id) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp clear_bands(target) do
    Targets.depopulate_target(target.id)
    band_ids = from(tb in TargetBand, where: tb.target_id == ^target.id, select: tb.id)

    Repo.delete_all(
      from(tbtg in TargetBandTraitGroup, where: tbtg.target_band_id in subquery(band_ids))
    )

    Repo.delete_all(from(tb in TargetBand, where: tb.target_id == ^target.id))
    :ok
  end

  defp copy_structure(target, dest, params) do
    attrs =
      %{
        "title" => params["title"] || "#{target.title} copy",
        "description" => target.description,
        "api_ref" => params["api_ref"]
      }
      |> Map.merge(owner_attrs(dest))

    with {:ok, clone} <- Targets.create_target(attrs) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Enum.each(Targets.get_bands_for_target(target.id), fn band ->
        {:ok, copied} =
          %TargetBand{}
          |> TargetBand.changeset(%{
            target_id: clone.id,
            is_bullseye: band.is_bullseye || "0",
            user_created_by: band.user_created_by
          })
          |> Repo.insert()

        rows =
          Enum.map(band.trait_groups, fn group ->
            %{
              target_band_id: copied.id,
              trait_group_id: group.id,
              created_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(TargetBandTraitGroup, rows)
      end)

      {:ok, present(clone)}
    end
  end

  defp plan(groups, drop_order) do
    by_id = Map.new(groups, &{&1.id, &1})
    drop_ids = Enum.map(drop_order, &int/1)

    cond do
      Enum.any?(drop_ids, &(not Map.has_key?(by_id, &1))) ->
        {:error, :drop_not_in_bullseye}

      true ->
        {planned, _} =
          Enum.reduce(drop_ids, {[groups], groups}, fn drop_id, {acc, current} ->
            next = Enum.reject(current, &(&1.id == drop_id))
            {acc ++ [next], next}
          end)

        if Enum.any?(planned, &(&1 == [])) do
          {:error, :empty_band}
        else
          {:ok, planned}
        end
    end
  end

  defp load_groups(ids, owner) when is_list(ids) do
    ids = Enum.map(ids, &int/1)
    groups = from(tg in TraitGroup, where: tg.id in ^ids) |> Repo.all()
    found = Map.new(groups, &{&1.id, &1})

    cond do
      Enum.any?(ids, &is_nil/1) or Enum.any?(ids, &(not Map.has_key?(found, &1))) ->
        {:error, :trait_group_not_found}

      Enum.any?(groups, &(not same_owner?(&1, owner) or not is_nil(&1.deactivated_at))) ->
        {:error, :trait_group_not_available}

      true ->
        {:ok, Enum.map(ids, &Map.fetch!(found, &1))}
    end
  end

  defp load_groups(_, _), do: {:error, :trait_group_not_found}

  defp band_plan(groups) do
    ids = Enum.map(groups, & &1.id)

    %{
      trait_group_ids: ids,
      estimated_reach: length(Targets.me_file_ids_matching_groups(ids)),
      reach_note: "Near-zero reach on a local database is expected."
    }
  end

  defp current_bands(target) do
    target.id
    |> Targets.get_bands_for_target()
    |> Enum.map(fn band -> %{trait_group_ids: Enum.map(band.trait_groups, & &1.id)} end)
  end

  defp present(target) do
    target = Repo.preload(target, [target_bands: [trait_groups: :traits]], force: true)
    bands = Targets.get_bands_for_target(target.id)

    %{
      id: target.id,
      api_ref: target.api_ref,
      title: target.title,
      description: target.description,
      marketer_id: target.marketer_id,
      creator_id: target.creator_id,
      population_status: target.population_status,
      archived_at: target.archived_at,
      frozen: Targets.is_frozen?(target.id),
      campaigns: Repo.all(from(c in Campaign, where: c.target_id == ^target.id, select: c.id)),
      bands:
        Enum.map(bands, fn band ->
          %{
            id: band.id,
            label: Targets.band_label(band, bands),
            trait_groups: Enum.map(band.trait_groups, & &1.id)
          }
        end)
    }
  end

  defp editable(target) do
    if Targets.is_frozen?(target.id), do: {:error, :frozen_target}, else: :ok
  end

  defp require_ref(ref) do
    cond do
      ref in [nil, ""] -> {:error, :api_ref_required}
      ApiRef.valid?(ref) -> :ok
      true -> {:error, :invalid_api_ref}
    end
  end

  defp owner(%{"marketer_id" => id}) when id not in [nil, ""], do: {:ok, {:marketer, int(id)}}
  defp owner(%{"creator_id" => id}) when id not in [nil, ""], do: {:ok, {:creator, int(id)}}
  defp owner(%{"owner" => %{"marketer_id" => id}}), do: {:ok, {:marketer, int(id)}}
  defp owner(%{"owner" => %{"creator_id" => id}}), do: {:ok, {:creator, int(id)}}
  defp owner(_), do: {:error, :owner_required}

  defp owner_of(%{marketer_id: id}) when is_integer(id), do: {:marketer, id}
  defp owner_of(%{creator_id: id}) when is_integer(id), do: {:creator, id}

  defp dest_owner(%{"dest_marketer_id" => id}, _target) when id not in [nil, ""],
    do: {:marketer, int(id)}

  defp dest_owner(%{"dest_creator_id" => id}, _target) when id not in [nil, ""],
    do: {:creator, int(id)}

  defp dest_owner(_params, target), do: owner_of(target)

  defp owner_attrs({:marketer, id}), do: %{"marketer_id" => id}
  defp owner_attrs({:creator, id}), do: %{"creator_id" => id}

  defp same_owner?(%{marketer_id: id}, {:marketer, id}), do: true
  defp same_owner?(%{creator_id: id}, {:creator, id}), do: true
  defp same_owner?(_, _), do: false

  defp filter_owner(query, %{"marketer_id" => id}) when id not in [nil, ""] do
    where(query, [t], t.marketer_id == ^int(id))
  end

  defp filter_owner(query, %{"creator_id" => id}) when id not in [nil, ""] do
    where(query, [t], t.creator_id == ^int(id))
  end

  defp filter_owner(query, _), do: query

  defp filter_archived(query, value) when value in [true, "true", "1"] do
    where(query, [t], not is_nil(t.archived_at))
  end

  defp filter_archived(query, _), do: where(query, [t], is_nil(t.archived_at))

  defp filter_prefix(query, prefix) when is_binary(prefix) and prefix != "" do
    where(query, [t], like(t.api_ref, ^"#{prefix}%"))
  end

  defp filter_prefix(query, _), do: query

  defp int(id) when is_integer(id), do: id

  defp int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil
end
