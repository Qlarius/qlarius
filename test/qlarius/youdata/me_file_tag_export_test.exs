defmodule Qlarius.YouData.MeFileTagExportTest do
  use ExUnit.Case, async: true

  alias Qlarius.YouData.MeFileTagExport
  alias Qlarius.YouData.MeFiles.{MeFile, MeFileTag}
  alias Qlarius.YouData.Traits.{Trait, TraitCategory}

  @mobile "+1 (555) 123-4567"

  test "json is the taxonomy and leaves out account identifiers" do
    json =
      me_file()
      |> MeFileTagExport.to_json(mobile_number: @mobile, exported_at: ~U[2026-07-09 12:00:00Z])

    assert json =~ ~s("schema": "qlarius.mefile")
    assert json =~ "Favorite Color"
    assert json =~ "Blue"
    assert json =~ "60614"

    refute json =~ "5551234567"
    refute json =~ "555-123-4567"
    refute json =~ "pat@example.com"
    refute json =~ "secret-token"
    refute json =~ "Pat Person"
    refute json =~ "1990-04-04"
    refute json =~ "REFCODE99"
    refute json =~ "424242"
    refute json =~ "434343"
    refute json =~ "Mobile Phone"
    refute json =~ "display_name"
    refute json =~ "sponster_token"
    refute json =~ "user_id"
  end

  defp me_file do
    category = %TraitCategory{id: 1, name: "General", display_order: 1}

    %MeFile{
      id: 434_343,
      user_id: 424_242,
      display_name: "Pat Person",
      date_of_birth: ~D[1990-04-04],
      sponster_token: "secret-token-xyz",
      referral_code: "REFCODE99",
      created_at: ~N[2020-01-02 03:04:05],
      me_file_tags: [
        tag(category, 10, "Favorite Color", "Blue"),
        tag(category, 11, "Home Zip Code", "60614"),
        tag(category, 12, "Mobile Phone", @mobile),
        tag(category, 13, "Email", "pat@example.com"),
        tag(category, 14, "Notes", "call me 5551234567 tonight")
      ]
    }
  end

  defp tag(category, id, name, value) do
    %MeFileTag{
      id: id,
      tag_value: value,
      added_date: ~N[2026-05-01 12:00:00],
      trait: %Trait{
        id: id,
        trait_name: name,
        display_order: id,
        trait_category: category
      }
    }
  end
end
