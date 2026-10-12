defmodule Qlarius.YouData.TraitAudit do
  @moduledoc """
  Before-and-after log of relationship, rule, and search-term writes.

  The admin API sets the token label for the request. Calls outside a request
  are not logged.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitAuditEntry
  alias Qlarius.YouData.Traits.TraitRelationship

  @rule_keys ~w(ideal_min_tags ideal_max_tags hard_max_tags unripe_days ripen_days stale_days expired_days skip_exempt nudge_text)

  def label, do: Process.get(:trait_audit_label)

  def list(trait_id) do
    Repo.all(
      from a in TraitAuditEntry,
        where: a.trait_id == ^trait_id or a.related_trait_id == ^trait_id,
        order_by: [desc: a.id]
    )
  end

  def to_json(%TraitAuditEntry{} = entry) do
    %{
      id: entry.id,
      token_label: entry.token_label,
      action: entry.action,
      trait_id: entry.trait_id,
      related_trait_id: entry.related_trait_id,
      before: entry.before,
      after: entry.after,
      inserted_at: entry.inserted_at
    }
  end

  def record_changes(%Trait{} = before, %Trait{} = after_trait, attrs) when is_map(attrs) do
    if label = label() do
      if Enum.any?(@rule_keys, &Map.has_key?(attrs, &1)) do
        prior = rules_map(before)
        next = rules_map(after_trait)

        if prior != next do
          insert(label, "rules", after_trait.id, nil, prior, next)
        end
      end

      if Map.has_key?(attrs, "search_terms") and before.search_terms != after_trait.search_terms do
        insert(
          label,
          "search_terms",
          after_trait.id,
          nil,
          %{"search_terms" => before.search_terms},
          %{"search_terms" => after_trait.search_terms}
        )
      end
    end

    :ok
  end

  def record_relationship(action, before_map, %TraitRelationship{} = relationship) do
    if label = label() do
      insert(
        label,
        action,
        relationship.trait_id,
        relationship.related_trait_id,
        before_map,
        snapshot(relationship)
      )
    end

    :ok
  end

  def record_relationship_deleted(%TraitRelationship{} = relationship) do
    if label = label() do
      insert(
        label,
        "relationship_deleted",
        relationship.trait_id,
        relationship.related_trait_id,
        snapshot(relationship),
        nil
      )
    end

    :ok
  end

  def snapshot(%TraitRelationship{} = relationship) do
    %{
      "id" => relationship.id,
      "trait_id" => relationship.trait_id,
      "related_trait_id" => relationship.related_trait_id,
      "kind" => relationship.kind,
      "severity" => relationship.severity,
      "note" => relationship.note
    }
  end

  defp rules_map(%Trait{} = trait) do
    Map.new(@rule_keys, fn key -> {key, Map.get(trait, String.to_existing_atom(key))} end)
  end

  defp insert(label, action, trait_id, related_trait_id, before_map, after_map) do
    %TraitAuditEntry{}
    |> Ecto.Changeset.change(%{
      token_label: label,
      action: action,
      trait_id: trait_id,
      related_trait_id: related_trait_id,
      before: before_map,
      after: after_map
    })
    |> Repo.insert!()
  end
end
