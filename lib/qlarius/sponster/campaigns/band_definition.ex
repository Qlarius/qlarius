defmodule Qlarius.Sponster.Campaigns.BandDefinition do
  @moduledoc """
  Content fingerprint of a target band, used to share population computation
  between bands that are content-identical.

  A band's population is a pure function of its trait groups' trait id sets: two
  bands whose groups hold the same sets of trait ids match exactly the same
  me_files, regardless of which target owns them, which org owns that target, or
  what the trait_group row ids are. So N copies of an audience need not be N
  population scans.

  ## The stored hash is an index, not a source of truth

  `target_bands.definition_hash` exists to find candidate twins cheaply. It can
  go stale — a trait group's membership can change without the band being
  re-populated — so it is never trusted on its own. Callers recompute from the
  actual trait groups before acting on a match. A stale hash on the band being
  populated is therefore a missed optimization, and a stale hash on a candidate
  source is caught by verification rather than silently copying wrong rows.
  """

  @doc """
  Fingerprints a band from its trait groups' trait id sets.

  Takes a list of trait id lists, one per trait group. Order within and between
  groups is irrelevant — a band means "hold a trait from every one of these
  groups" — so both levels are sorted before hashing.

  Returns `nil` for a band that cannot match anybody: no trait groups at all, or
  any group with no traits. Both workers already treat such bands as matching
  nobody, and marking them ineligible keeps unrelated degenerate bands from
  being mistaken for twins of each other.
  """
  def hash(trait_id_sets) when is_list(trait_id_sets) do
    normalized =
      Enum.map(trait_id_sets, fn ids -> ids |> Enum.uniq() |> Enum.sort() end)

    if normalized == [] or Enum.any?(normalized, &(&1 == [])) do
      nil
    else
      normalized
      |> Enum.sort()
      |> Enum.map_join("|", &Enum.join(&1, ","))
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
    end
  end

  @doc """
  Fingerprints a band that has `trait_groups: :traits` preloaded.
  """
  def hash_for_band(%{trait_groups: trait_groups}) when is_list(trait_groups) do
    trait_groups
    |> Enum.map(fn group -> Enum.map(group.traits, & &1.id) end)
    |> hash()
  end

  @doc """
  Whether a set of band hashes can take part in reuse.

  Requires every hash to be present and all of them distinct. Distinctness
  matters because reuse maps source bands onto destination bands *by hash*; two
  bands in one target sharing a fingerprint would make that mapping ambiguous.
  Such a target is degenerate anyway — it holds two rings that match identically.
  """
  def reusable?(hashes) when is_list(hashes) do
    hashes != [] and
      not Enum.any?(hashes, &is_nil/1) and
      length(Enum.uniq(hashes)) == length(hashes)
  end
end
