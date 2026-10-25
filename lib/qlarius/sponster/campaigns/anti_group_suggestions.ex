defmodule Qlarius.Sponster.Campaigns.AntiGroupSuggestions do
  @moduledoc """
  Suggests Anti-Trait Groups for a target by following directed `excludes`
  relationships from the traits its include groups hold.

  The suggestion is advice. A target with suggestions is never marked wrong;
  the marketer may confirm some, edit them, or dismiss a topic, and a
  dismissal is remembered for that target and topic.
  """

  import Ecto.Query

  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    BandMatch,
    Target,
    Targets,
    TargetSuggestionDismissal
  }

  alias Qlarius.YouData.TraitRelationships
  alias Qlarius.YouData.Traits

  @doc """
  Suggestions for a target, grouped by the excluded answers' topic.

  Returns `%{topics: [...], dismissed: [...], frozen?: boolean}` where each
  topic is `%{parent, traits: [%{trait, severity, because: [names], note}]}`
  sorted hard first. Answers already held by an Anti-Trait Group on the target
  are left out, and answers held by an include group are never suggested.
  """
  def for_target(target_id) do
    bands = Targets.get_bands_for_target(target_id)
    groups = bands |> Enum.flat_map(& &1.trait_groups) |> Enum.uniq_by(& &1.id)

    include_trait_ids =
      groups
      |> BandMatch.include_groups()
      |> Enum.flat_map(& &1.traits)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    anti_trait_ids =
      groups
      |> BandMatch.anti_groups()
      |> Enum.flat_map(& &1.traits)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    dismissed_ids = dismissed_parent_ids(target_id)

    topics =
      include_trait_ids
      |> TraitRelationships.excludes_from()
      |> Enum.reject(
        &(&1.related_trait_id in anti_trait_ids or &1.related_trait_id in include_trait_ids)
      )
      |> Enum.group_by(& &1.related_trait_id)
      |> Enum.map(fn {_trait_id, rows} ->
        first = List.first(rows)

        %{
          trait: first.related_trait,
          severity: if(Enum.any?(rows, &(&1.severity == "hard")), do: "hard", else: "soft"),
          because: rows |> Enum.map(& &1.trait.trait_name) |> Enum.uniq(),
          note: rows |> Enum.map(& &1.note) |> Enum.reject(&is_nil/1) |> List.first()
        }
      end)
      |> Enum.group_by(& &1.trait.parent_trait_id)
      |> Enum.map(fn {_parent_id, traits} ->
        %{
          parent: List.first(traits).trait.parent_trait,
          traits: Enum.sort_by(traits, &{severity_rank(&1.severity), &1.trait.display_order})
        }
      end)
      |> Enum.sort_by(&{(&1.parent && &1.parent.display_order) || 0, parent_name(&1)})

    {dismissed, open} = Enum.split_with(topics, &(parent_id(&1) in dismissed_ids))

    %{topics: open, dismissed: dismissed, frozen?: Targets.is_frozen?(target_id)}
  end

  @doc """
  Number of suggested answers across open topics.
  """
  def count(%{topics: topics}), do: topics |> Enum.flat_map(& &1.traits) |> length()

  def dismissed_parent_ids(target_id) do
    from(d in TargetSuggestionDismissal,
      where: d.target_id == ^target_id,
      select: d.parent_trait_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def dismiss(target_id, parent_trait_id) do
    %TargetSuggestionDismissal{}
    |> TargetSuggestionDismissal.changeset(%{
      target_id: target_id,
      parent_trait_id: parent_trait_id,
      dismissed_at: DateTime.utc_now(:second)
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:target_id, :parent_trait_id])
  end

  def reopen(target_id, parent_trait_id) do
    from(d in TargetSuggestionDismissal,
      where: d.target_id == ^target_id and d.parent_trait_id == ^parent_trait_id
    )
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Creates Anti-Trait Groups from chosen answers and attaches them to bands.

    * `selections` — `[%{parent_trait_id, trait_ids, title}]`, one per topic
    * `shape` — `:per_topic` (one group per selection) or `:combined` (one
      group holding every chosen answer; `title:` names it)
    * `band_ids:` — bands to attach to, default every band on the target

  All or nothing: a refusal on any band rolls back the groups.
  """
  def confirm(%Target{} = target, selections, shape, opts \\ []) do
    owner = owner_attrs(target)
    selections = Enum.reject(selections, &(&1.trait_ids == []))

    cond do
      selections == [] ->
        {:error, :traits_required}

      Targets.is_frozen?(target.id) ->
        {:error, :frozen_target}

      true ->
        Repo.transaction(fn ->
          selections
          |> drafts(shape, opts)
          |> Enum.map(fn draft ->
            with {:ok, group} <- Traits.create_trait_group(Map.merge(draft, owner)),
                 {:ok, _band_ids} <-
                   Targets.attach_anti_group(target.id, group.id, band_ids: opts[:band_ids]) do
              Repo.preload(group, :traits)
            else
              {:error, reason} -> Repo.rollback(reason)
            end
          end)
        end)
    end
  end

  defp drafts(selections, :combined, opts) do
    trait_ids = selections |> Enum.flat_map(& &1.trait_ids) |> Enum.uniq()

    [
      %{
        "title" => present(opts[:title]) || combined_title(selections),
        "role" => "anti",
        "parent_trait_id" => single_parent(selections),
        "trait_ids" => trait_ids
      }
    ]
  end

  defp drafts(selections, :per_topic, _opts) do
    Enum.map(selections, fn selection ->
      %{
        "title" => present(selection[:title]) || default_title(selection),
        "role" => "anti",
        "parent_trait_id" => selection.parent_trait_id,
        "trait_ids" => selection.trait_ids
      }
    end)
  end

  defp single_parent([%{parent_trait_id: id}]), do: id
  defp single_parent(_), do: nil

  def default_title(%{parent_name: name}) when is_binary(name), do: "Keep out · #{name}"
  def default_title(%{parent_trait_id: id}), do: "Keep out · #{Traits.get_trait!(id).trait_name}"

  def combined_title(selections) do
    names =
      Enum.map(selections, fn
        %{parent_name: name} when is_binary(name) -> name
        %{parent_trait_id: id} -> Traits.get_trait!(id).trait_name
      end)

    "Keep out · " <> Enum.join(names, ", ")
  end

  defp present(nil), do: nil

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp owner_attrs(%{marketer_id: id}) when is_integer(id), do: %{"marketer_id" => id}
  defp owner_attrs(%{creator_id: id}) when is_integer(id), do: %{"creator_id" => id}

  defp severity_rank("hard"), do: 0
  defp severity_rank(_), do: 1

  defp parent_id(%{parent: %{id: id}}), do: id
  defp parent_id(_), do: nil

  defp parent_name(%{parent: %{trait_name: name}}), do: name
  defp parent_name(_), do: ""
end
