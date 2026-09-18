defmodule Qlarius.Tiqit.CreatorAudienceStartersTest do
  use Qlarius.DataCase, async: true

  import Qlarius.TargetingFixtures

  alias Qlarius.System
  alias Qlarius.Tiqit.CreatorAudienceStarters

  test "parses comma-separated parent IDs in display order and drops missing ones" do
    first = parent_trait_fixture("Formats")
    second = parent_trait_fixture("Topics")

    System.set_global_variable(
      "CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS",
      "#{first.id}, #{second.id}, 999999, not-an-id"
    )

    System.set_global_variable("CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS", "")

    assert Enum.map(CreatorAudienceStarters.content_parent_traits(), & &1.id) == [
             first.id,
             second.id
           ]

    assert CreatorAudienceStarters.audience_parent_traits() == []
    assert CreatorAudienceStarters.configured?()
  end

  test "is hidden when both globals are empty" do
    System.set_global_variable("CREATOR_CONTENT_TAG_PARENT_TRAIT_IDS", "")
    System.set_global_variable("CREATOR_AUDIENCE_TAG_PARENT_TRAIT_IDS", "")

    refute CreatorAudienceStarters.configured?()
    assert CreatorAudienceStarters.content_parent_traits() == []
    assert CreatorAudienceStarters.audience_parent_traits() == []
  end
end
