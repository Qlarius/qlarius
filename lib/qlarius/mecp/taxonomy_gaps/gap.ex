defmodule Qlarius.MeCP.TaxonomyGaps.Gap do
  @moduledoc """
  One de-identified taxonomy-gap signal: a subject an assistant raised that
  the trait taxonomy doesn't cover. No person, grant or MeFile link; see
  `Qlarius.MeCP.TaxonomyGaps`.
  """
  use Ecto.Schema

  @sources ~w(search ask suggest observed)
  @reasons ~w(no_match weak_match unknown_trait not_askable)

  schema "mecp_taxonomy_gaps" do
    field :source, :string
    field :reason, :string
    field :subject, :string
    field :subject_key, :string
    field :proposed_values, {:array, :string}, default: []
    field :person_key, :string
    field :occurred_on, :date

    belongs_to :nearest_trait, Qlarius.YouData.Traits.Trait
    belongs_to :mecp_client, Qlarius.MeCP.Clients.Client
  end

  def sources, do: @sources
  def reasons, do: @reasons
end
