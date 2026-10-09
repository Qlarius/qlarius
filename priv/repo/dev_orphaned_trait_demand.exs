# Dev only: makes an orphaned "Favorite Color" trait (a survey question in no
# active survey) and replays assistants trying to suggest it, so the Qai
# Oracle admin page's "Orphaned Traits Still Wanted" panel has something to
# show locally. Production has the real case. Safe to re-run.
#
# Runs without starting the app, so no endpoint, jobs or watchers start:
#   mix run --no-start priv/repo/dev_orphaned_trait_demand.exs

import Ecto.Query

alias Qlarius.MeCP.Grants.Grant
alias Qlarius.MeCP.{Suggestions, TaxonomyGaps}
alias Qlarius.MeCP.Suggestions.TagSuggestion
alias Qlarius.Repo
alias Qlarius.YouData.Surveys
alias Qlarius.YouData.Surveys.SurveyQuestion
alias Qlarius.YouData.Traits.{Trait, TraitCategory}

# .env can point DATABASE_URL at a remote database: never write there
config = Repo.config()

unless config[:hostname] in ["localhost", "127.0.0.1"] and config[:database] == "qlarius_dev" do
  Mix.raise("Refusing to run against #{config[:hostname]}/#{config[:database]}")
end

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Repo.start_link(pool_size: 2)
# Grants resolve their effective MeFile through users, whose phone is encrypted
{:ok, _} = Qlarius.Vault.start_link()

category =
  Repo.one(from c in TraitCategory, where: c.name == "General Information", limit: 1) ||
    Repo.one(from c in TraitCategory, order_by: c.display_order, limit: 1)

trait =
  Repo.one(
    from t in Trait,
      where: t.trait_name == "Favorite Color" and is_nil(t.parent_trait_id),
      limit: 1
  ) ||
    Repo.insert!(%Trait{
      trait_name: "Favorite Color",
      input_type: "single_select",
      display_order: 99,
      trait_category_id: category.id,
      modified_by: 0,
      added_by: 0
    })

for {name, order} <- Enum.with_index(~w(Blue Green Red Purple Black), 1),
    not Repo.exists?(
      from t in Trait, where: t.parent_trait_id == ^trait.id and t.trait_name == ^name
    ) do
  Repo.insert!(%Trait{
    trait_name: name,
    input_type: "single_select",
    display_order: order,
    parent_trait_id: trait.id,
    trait_category_id: category.id,
    modified_by: 0,
    added_by: 0
  })
end

# A question, but in no survey: that's what makes it orphaned
unless Repo.exists?(from q in SurveyQuestion, where: q.trait_id == ^trait.id) do
  Repo.insert!(%SurveyQuestion{
    text: "What's your favorite color?",
    trait_id: trait.id,
    # Legacy bytea column holding ASCII "1" for active.
    active: "1",
    display_order: 1,
    added_by: 0,
    modified_by: 0
  })
end

if Surveys.surveyed_trait?(trait.id) do
  Mix.raise("Favorite Color is in an active survey here, so it isn't orphaned")
end

now = DateTime.utc_now()

grants =
  Repo.all(
    from g in Grant,
      where: is_nil(g.revoked_at) and (is_nil(g.expires_at) or g.expires_at > ^now),
      order_by: g.id
  )

if grants == [], do: Mix.raise("No active MeCP grants in this database to replay through")

# One suggestion filed the old way, before the orphan rule (like production's).
# Dismissed, so it never surfaces in anyone's Builder.
[first | _] = grants

unless Repo.exists?(from s in TagSuggestion, where: s.trait_id == ^trait.id) do
  Repo.insert!(%TagSuggestion{
    mecp_grant_id: first.id,
    me_file_id: first.me_file_id,
    trait_id: trait.id,
    proposed_values: ["Blue"],
    status: "dismissed",
    source: "observed",
    resolved_at: DateTime.truncate(now, :second)
  })
end

# Each assistant tries again now: refused as not_askable, and recorded
for grant <- grants do
  result = Suggestions.create_suggestion(grant, trait.id, %{proposed_values: ["Blue"]})
  IO.puts("grant #{grant.id}: #{inspect(result)}")
end

IO.puts("\nOrphaned traits still wanted (30 days):")

for row <- TaxonomyGaps.orphan_demand(30) do
  IO.puts("  #{row.trait}: #{row.people} people, #{row.mentions} mentions, last #{row.last_seen}")
end
