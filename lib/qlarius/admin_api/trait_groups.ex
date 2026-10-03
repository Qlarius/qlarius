defmodule Qlarius.AdminApi.TraitGroups do
  @moduledoc """
  Trait groups for the admin campaign API.

  Groups are built before targets. A group belongs to exactly one marketer or
  creator. Traits are active children of `parent_trait_id` when that is set.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.Idempotent
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{AudienceBuilder, TargetBandTraitGroup, TraitGroup}
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait

  @fields ~w(title description parent_trait_id)

  def list(params) do
    owner = owner(params)

    from(tg in TraitGroup, order_by: [asc: tg.title, asc: tg.id], preload: [:traits])
    |> owner_filter(owner)
    |> prefix_filter(params["api_ref_prefix"])
    |> Repo.all()
    |> with_counts()
  end

  def fetch(id) do
    case Repo.get(TraitGroup, id) do
      nil -> {:error, :not_found}
      group -> {:ok, group |> Repo.preload(:traits) |> List.wrap() |> with_counts() |> hd()}
    end
  end

  def create(params, opts) do
    with {:ok, owner} <- require_owner(params),
         {:ok, trait_ids} <-
           AudienceBuilder.validate_traits(params["parent_trait_id"], params["trait_ids"]) do
      Idempotent.create(TraitGroup, params,
        fields: @fields,
        dry_run: opts[:dry_run],
        on_existing: params["on_existing"],
        owned?: &same_owner?(&1, owner),
        locked: &lock_reason/1,
        extra_differences: &trait_difference(&1, trait_ids),
        preview: &preview(&1, owner, trait_ids),
        preview_update: fn group, _attrs, differences ->
          {:ok,
           %{
             result: "would_update",
             record: Repo.preload(group, :traits),
             differences: differences
           }}
        end,
        insert: fn attrs -> insert(attrs, owner, trait_ids) end,
        update: fn group, attrs -> apply_update(group, attrs, trait_ids, opts) end
      )
    end
  end

  def update(group, params, opts) do
    cond do
      Map.has_key?(params, "api_ref") && params["api_ref"] != group.api_ref ->
        {:error, :api_ref_immutable}

      reason = lock_reason(group) ->
        {:error, reason}

      opts[:dry_run] ->
        {:ok, %{result: "would_update", record: Repo.preload(group, :traits), differences: %{}}}

      true ->
        case Traits.update_trait_group(group, Map.take(params, @fields)) do
          {:ok, group} ->
            {:ok,
             %{
               result: "updated",
               record:
                 group
                 |> Repo.preload(:traits, force: true)
                 |> List.wrap()
                 |> with_counts()
                 |> hd(),
               differences: %{}
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def change_traits(group, params, opts) do
    add = List.wrap(params["add"])
    remove = List.wrap(params["remove"])

    frozen_ids = AudienceBuilder.frozen?(group.id)

    cond do
      frozen_ids != [] ->
        {:error, {:frozen_target, frozen_ids}}

      AudienceBuilder.shared?(group.id) ->
        {:error, :trait_group_shared}

      true ->
        current = group |> Repo.preload(:traits) |> Map.fetch!(:traits) |> Enum.map(& &1.id)
        trait_ids = (current ++ int_list(add)) -- int_list(remove)

        with {:ok, trait_ids} <- AudienceBuilder.validate_traits(group.parent_trait_id, trait_ids) do
          if opts[:dry_run] do
            {:ok, %{result: "would_update", trait_ids: trait_ids}}
          else
            AudienceBuilder.replace_traits!(group, trait_ids)
            {:ok, %{result: "updated", record: Repo.preload(group, :traits, force: true)}}
          end
        end
    end
  end

  def delete(group, opts) do
    bands =
      from(tbtg in TargetBandTraitGroup,
        where: tbtg.trait_group_id == ^group.id,
        select: count(tbtg.id)
      )
      |> Repo.one()

    cond do
      bands > 0 ->
        {:error, {:has_dependents, %{target_bands: bands}}}

      opts[:dry_run] ->
        {:ok, %{result: "would_delete", removes: %{trait_group: group.id}}}

      true ->
        Repo.delete_all(
          from(tgt in Qlarius.Sponster.Campaigns.TraitGroupTrait,
            where: tgt.trait_group_id == ^group.id
          )
        )

        with {:ok, _} <- Traits.delete_trait_group(group) do
          {:ok, %{result: "deleted", removes: %{trait_group: group.id}}}
        end
    end
  end

  def search_zips(query) do
    parent =
      Repo.one(
        from(t in Trait,
          where:
            t.input_type == "single_select_zip" and is_nil(t.parent_trait_id) and
              t.is_active == true,
          limit: 1
        )
      )

    cond do
      query in [nil, ""] or String.length(String.trim(to_string(query))) < 2 ->
        {:error, :zip_query_too_short}

      is_nil(parent) ->
        {:error, :zip_parent_not_found}

      true ->
        {:ok,
         %{parent_trait_id: parent.id, zip_codes: Traits.search_zip_codes(parent.id, query, 50)}}
    end
  end

  defp insert(attrs, owner, trait_ids) do
    attrs =
      attrs
      |> Map.take(["api_ref", "title", "description", "parent_trait_id"])
      |> Map.merge(owner_attrs(owner))
      |> Map.put("trait_ids", trait_ids)

    with {:ok, group} <- Traits.create_trait_group(attrs) do
      {:ok, Repo.preload(group, :traits, force: true)}
    end
  end

  defp apply_update(group, attrs, trait_ids, opts) do
    if opts[:dry_run] do
      {:ok, group}
    else
      with {:ok, group} <- Traits.update_trait_group(group, Map.take(attrs, @fields)) do
        AudienceBuilder.replace_traits!(group, trait_ids)
        {:ok, Repo.preload(group, :traits, force: true)}
      end
    end
  end

  defp preview(attrs, owner, trait_ids) do
    attrs =
      attrs
      |> Map.take(["api_ref", "title", "description", "parent_trait_id"])
      |> Map.merge(owner_attrs(owner))

    case TraitGroup.changeset(%TraitGroup{}, attrs) do
      %{valid?: true} = changeset ->
        group = Ecto.Changeset.apply_changes(changeset)
        {:ok, %{group | traits: Enum.map(trait_ids, &%Trait{id: &1})}}

      changeset ->
        {:error, changeset}
    end
  end

  defp trait_difference(group, trait_ids) do
    current =
      group |> Repo.preload(:traits) |> Map.fetch!(:traits) |> Enum.map(& &1.id) |> Enum.sort()

    if Enum.sort(trait_ids) == current do
      %{}
    else
      %{"trait_ids" => %{"current" => current, "requested" => Enum.sort(trait_ids)}}
    end
  end

  defp require_owner(params) do
    case owner(params) do
      nil -> {:error, :owner_required}
      owner -> {:ok, owner}
    end
  end

  defp owner(%{"marketer_id" => id}) when id not in [nil, ""], do: {:marketer, int(id)}
  defp owner(%{"creator_id" => id}) when id not in [nil, ""], do: {:creator, int(id)}
  defp owner(_), do: nil

  defp owner_attrs({:marketer, id}), do: %{"marketer_id" => id}
  defp owner_attrs({:creator, id}), do: %{"creator_id" => id}

  defp same_owner?(group, {:marketer, id}), do: group.marketer_id == id
  defp same_owner?(group, {:creator, id}), do: group.creator_id == id

  defp owner_filter(query, {:marketer, id}), do: where(query, [tg], tg.marketer_id == ^id)
  defp owner_filter(query, {:creator, id}), do: where(query, [tg], tg.creator_id == ^id)
  defp owner_filter(query, _), do: query

  defp prefix_filter(query, prefix) when is_binary(prefix) and prefix != "" do
    where(query, [tg], like(tg.api_ref, ^"#{prefix}%"))
  end

  defp prefix_filter(query, _), do: query

  defp with_counts(groups) do
    counts = Traits.me_file_counts_for_trait_groups(Enum.map(groups, & &1.id))
    Enum.map(groups, &Map.put(&1, :me_file_count, Map.get(counts, &1.id, 0)))
  end

  defp lock_reason(group) do
    case AudienceBuilder.frozen?(group.id) do
      [] -> nil
      ids -> {:frozen_target, ids}
    end
  end

  defp int_list(ids), do: ids |> Enum.map(&int/1) |> Enum.reject(&is_nil/1)

  defp int(id) when is_integer(id), do: id

  defp int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil
end
