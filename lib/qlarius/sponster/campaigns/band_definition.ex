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

  Returns `nil` for a band that cannot match anybody: no include groups at all,
  or any include group with no traits. Both workers already treat such bands as
  matching nobody, and marking them ineligible keeps unrelated degenerate bands
  from being mistaken for twins of each other.

  Anti-Trait Groups are passed separately as `anti_id_sets`. A band with none
  hashes exactly as it did before anti-groups existed, so stored hashes stay
  valid. When any anti-group is present a polarity marker and the anti sets join
  the fingerprint, since "Vegans" as an include and "Vegans" as an anti match
  different people. An empty anti-group removes nobody and is dropped before
  hashing.
  """
  def hash(trait_id_sets, anti_id_sets \\ []) when is_list(trait_id_sets) do
    normalized = normalize(trait_id_sets)
    anti = anti_id_sets |> normalize() |> Enum.reject(&(&1 == []))

    if normalized == [] or Enum.any?(normalized, &(&1 == [])) do
      nil
    else
      include_part = normalized |> Enum.sort() |> Enum.map_join("|", &Enum.join(&1, ","))

      material =
        case anti do
          [] ->
            include_part

          _ ->
            include_part <>
              "!" <> (anti |> Enum.sort() |> Enum.map_join("|", &Enum.join(&1, ",")))
        end

      material
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
    end
  end

  defp normalize(id_sets), do: Enum.map(id_sets, fn ids -> ids |> Enum.uniq() |> Enum.sort() end)

  @doc """
  Fingerprints a band that has `trait_groups: :traits` preloaded.
  """
  def hash_for_band(%{trait_groups: trait_groups}) when is_list(trait_groups) do
    {anti, include} = Enum.split_with(trait_groups, &(&1.role == "anti"))

    hash(
      Enum.map(include, fn group -> Enum.map(group.traits, & &1.id) end),
      Enum.map(anti, fn group -> Enum.map(group.traits, & &1.id) end)
    )
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
