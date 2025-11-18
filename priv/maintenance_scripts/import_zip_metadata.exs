# Maintenance Script: Import Zip Code Metadata
#
# This script reads zip code data from a CSV file and updates the meta_1, meta_2, and meta_3
# fields for trait records that are children of "Home Zip Code" (trait_id 4) or
# "Work Zip Code" (trait_id 5).
#
# Usage:
#   mix run priv/maintenance_scripts/import_zip_metadata.exs
#
# The script will:
# - Read from priv/data/zip_codes_minimal.csv.gz (compressed)
# - Match zip codes to trait_name values
# - Update existing traits with metadata
# - Create new traits for any zip codes missing from the database
# - Set meta_1 = "City, State" (e.g., "Austin, TX")
# - Set meta_2 = acceptable_cities (optional)
# - Set meta_3 = type (e.g., "STANDARD", "UNIQUE")
# - Log progress and results

alias Qlarius.Repo
alias Qlarius.YouData.Traits.Trait
import Ecto.Query

defmodule ZipMetadataImporter do
  def run do
    IO.puts("\n========================================")
    IO.puts("Zip Code Metadata Import Script")
    IO.puts("========================================\n")

    csv_path = Path.join(:code.priv_dir(:qlarius), "data/zip_codes_minimal.csv.gz")

    unless File.exists?(csv_path) do
      IO.puts("❌ Error: CSV file not found at #{csv_path}")
      System.halt(1)
    end

    IO.puts("📂 Reading gzipped CSV file: #{csv_path}")
    IO.puts("⏳ This may take a moment...\n")

    # Read CSV and build zip code map
    zip_data = parse_csv_gz(csv_path)
    IO.puts("✅ Parsed #{map_size(zip_data)} zip codes from CSV\n")

    # Get all zip code traits (children of trait 4 or 5)
    IO.puts("🔍 Fetching zip code traits from database...")

    zip_traits =
      Repo.all(
        from t in Trait,
          where: t.parent_trait_id in [4, 5],
          select: t
      )

    IO.puts("✅ Found #{length(zip_traits)} zip code traits in database\n")

    # Process updates
    IO.puts("🔄 Updating existing trait metadata...\n")
    update_results = update_traits(zip_traits, zip_data)

    # Create missing traits
    IO.puts("\n🆕 Creating missing zip code traits...\n")
    existing_zips = MapSet.new(zip_traits, & &1.trait_name)
    create_results = create_missing_traits(zip_data, existing_zips)

    # Combine results
    results = %{
      updated: update_results.updated,
      not_found: update_results.not_found,
      created: create_results.created,
      errors: update_results.errors ++ create_results.errors
    }

    # Display results
    display_results(results)
  end

  defp parse_csv_gz(csv_path) do
    csv_path
    |> File.stream!([:compressed])
    |> Stream.drop(1)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&parse_csv_line/1)
    |> Stream.filter(&(&1 != nil))
    |> Enum.reduce(%{}, fn {zip, data}, acc ->
      Map.put(acc, zip, data)
    end)
  end

  defp parse_csv_line(line) do
    parts = String.split(line, ",", parts: 10)

    case parts do
      [zip, type, _decom, primary_city, acceptable, _unacceptable, state | _rest] ->
        zip = String.trim(zip)
        type = String.trim(type)
        primary_city = String.trim(primary_city)
        acceptable = String.trim(acceptable)
        state = String.trim(state)

        # Build meta_1: "City, State"
        meta_1 = "#{primary_city}, #{state}"

        # meta_2: acceptable_cities, nil if empty
        meta_2 = if acceptable == "", do: nil, else: acceptable

        # meta_3: type
        meta_3 = type

        {zip, %{meta_1: meta_1, meta_2: meta_2, meta_3: meta_3}}

      _ ->
        nil
    end
  end

  defp update_traits(traits, zip_data) do
    total = length(traits)

    traits
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{updated: 0, not_found: 0, errors: []},
      fn {trait, index}, acc ->
        if rem(index, 1000) == 0 do
          IO.puts("  Progress: #{index}/#{total} traits processed...")
        end

        case Map.get(zip_data, trait.trait_name) do
          nil ->
            %{acc | not_found: acc.not_found + 1}

          data ->
            case update_trait(trait, data) do
              {:ok, _} ->
                %{acc | updated: acc.updated + 1}

              {:error, reason} ->
                error_msg = "Trait #{trait.id} (#{trait.trait_name}): #{inspect(reason)}"
                %{acc | errors: [error_msg | acc.errors]}
            end
        end
      end
    )
  end

  defp update_trait(trait, data) do
    trait
    |> Ecto.Changeset.change(%{
      meta_1: data.meta_1,
      meta_2: data.meta_2,
      meta_3: data.meta_3
    })
    |> Repo.update()
  end

  defp create_missing_traits(zip_data, existing_zips) do
    missing_zips =
      zip_data
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(existing_zips, &1))

    IO.puts("  Found #{length(missing_zips)} zip codes to create\n")

    if length(missing_zips) == 0 do
      %{created: 0, errors: []}
    else
      # Get max display_order for zip code traits
      max_display_order =
        Repo.one(
          from t in Trait,
            where: t.parent_trait_id in [4, 5],
            select: max(t.display_order)
        ) || 0

      missing_zips
      |> Enum.with_index(1)
      |> Enum.reduce(
        %{created: 0, errors: []},
        fn {zip, index}, acc ->
          if rem(index, 1000) == 0 do
            IO.puts("  Progress: #{index}/#{length(missing_zips)} new traits processed...")
          end

          data = Map.get(zip_data, zip)

          case create_trait(zip, data, max_display_order + index) do
            {:ok, _} ->
              %{acc | created: acc.created + 1}

            {:error, reason} ->
              error_msg = "Zip #{zip}: #{inspect(reason)}"
              %{acc | errors: [error_msg | acc.errors]}
          end
        end
      )
    end
  end

  defp create_trait(zip, data, display_order) do
    %Trait{}
    |> Trait.changeset(%{
      trait_name: zip,
      parent_trait_id: 4,
      trait_category_id: 1,
      input_type: "single_select",
      is_active: true,
      display_order: display_order,
      added_by: 1,
      modified_by: 1,
      meta_1: data.meta_1,
      meta_2: data.meta_2,
      meta_3: data.meta_3
    })
    |> Repo.insert()
  end

  defp display_results(results) do
    IO.puts("\n========================================")
    IO.puts("Import Complete!")
    IO.puts("========================================\n")
    IO.puts("✅ Successfully updated: #{results.updated} traits")
    IO.puts("🆕 Successfully created: #{results.created} new traits")
    IO.puts("⚠️  Zip codes not found in CSV: #{results.not_found} traits")
    IO.puts("❌ Errors: #{length(results.errors)}")

    if length(results.errors) > 0 do
      IO.puts("\n📋 Error Details:")

      Enum.each(results.errors, fn error ->
        IO.puts("  - #{error}")
      end)
    end

    IO.puts("\n✨ Done!\n")
  end
end

# Run the importer
ZipMetadataImporter.run()
