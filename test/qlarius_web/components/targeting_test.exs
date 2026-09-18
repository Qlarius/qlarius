defmodule QlariusWeb.Components.TargetingTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Components.Targeting

  test "trait_ids_from_params parses list and scalar ids" do
    assert Targeting.trait_ids_from_params(%{"trait_ids" => ["12", "34"]}) == [12, 34]
    assert Targeting.trait_ids_from_params(%{"trait_ids" => "12"}) == [12]
    assert Targeting.trait_ids_from_params(%{"trait_ids" => 12}) == [12]
    assert Targeting.trait_ids_from_params(%{}) == []
  end

  test "trait_ids_target? matches checkbox names" do
    assert Targeting.trait_ids_target?(["trait_ids"])
    assert Targeting.trait_ids_target?("trait_ids[]")
    refute Targeting.trait_ids_target?(["trait_group"])
    refute Targeting.trait_ids_target?(["search"])
  end
end
