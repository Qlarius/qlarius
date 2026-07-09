defmodule Qlarius.MeCP.Export do
  @moduledoc """
  Open schema v1: a MeFile as portable JSON, matching the taxonomy structure
  (category > trait > values) with dates included from v1 per the build plan.

  Like `Capsules`, this is a pure function over preloaded data (use
  `Qlarius.MeCP.load_me_file/1`) and reuses the capsule build, so ordering is
  deterministic and the same effective-trait resolution applies. Unlike
  capsules, exports are always full-scope: this is the owner exporting their
  own data, not a counterparty reading through a grant.
  """

  alias Qlarius.MeCP.Capsules
  alias Qlarius.MeCP.Capsules.Scope
  alias Qlarius.YouData.MeFiles.MeFile

  @schema_version "1"

  @doc """
  Builds the export map for a preloaded MeFile. Encode with `Jason.encode!/1`.
  Options: `:exported_at` (DateTime, defaults to now).
  """
  @spec build(MeFile.t(), keyword()) :: map()
  def build(%MeFile{} = me_file, opts \\ []) do
    exported_at = Keyword.get_lazy(opts, :exported_at, &DateTime.utc_now/0)
    capsule = Capsules.build(me_file, Scope.all())

    %{
      "schema" => "qlarius.mefile",
      "schema_version" => @schema_version,
      "exported_at" => DateTime.to_iso8601(DateTime.truncate(exported_at, :second)),
      "me_file" => %{
        "created_at" => format_naive(me_file.created_at),
        "categories" =>
          for category <- capsule.categories do
            %{
              "id" => category.id,
              "name" => category.name,
              "display_order" => category.display_order,
              "traits" =>
                for trait <- category.traits do
                  %{
                    "id" => trait.id,
                    "name" => trait.name,
                    "display_order" => trait.display_order,
                    "values" =>
                      for value <- trait.values do
                        %{
                          "value" => value.text,
                          "added_date" => format_naive(value.added_date)
                        }
                      end
                  }
                end
            }
          end
      }
    }
  end

  defp format_naive(nil), do: nil
  defp format_naive(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_naive(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_naive(%Date{} = d), do: Date.to_iso8601(d)
end
