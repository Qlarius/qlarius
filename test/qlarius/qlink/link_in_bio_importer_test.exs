defmodule Qlarius.Qlink.LinkInBioImporterTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Creators
  alias Qlarius.Qlink
  alias Qlarius.Qlink.LinkInBio.Draft
  alias Qlarius.Qlink.LinkInBio.ParseHelpers
  alias Qlarius.Qlink.LinkInBioImporter

  import Qlarius.AccountsFixtures, only: [valid_user_password: 0]

  test "creates named sections first, nests links, and puts Tip Jar in Support" do
    creator = creator_with_recipient!()

    draft = %Draft{
      platform: :linktree,
      source_url: "https://linktr.ee/michsim",
      suggested_alias: "libio-#{System.unique_integer([:positive])}",
      title: "MichSim",
      sections: [
        ParseHelpers.section_map("The Optimization Edit", [
          ParseHelpers.link_map("Bathhouse", "https://example.com/bathhouse")
        ]),
        ParseHelpers.section_map("Shop My Looks", [
          ParseHelpers.link_map("Amazon", "https://example.com/amazon")
        ])
      ]
    }

    assert {:ok, page} = LinkInBioImporter.import!(draft, creator)

    sections = Qlink.list_page_sections(page.id)
    links = Qlink.list_page_links(page.id)

    assert Enum.map(sections, & &1.title) == [
             "The Optimization Edit",
             "Shop My Looks",
             "Support"
           ]

    support = List.last(sections)
    assert support.description == "Show love and support for your favorite creators."

    by_section =
      links
      |> Enum.group_by(& &1.qlink_section_id)
      |> Map.new(fn {id, grouped} -> {id, Enum.map(grouped, &{&1.type, &1.title})} end)

    opt = Enum.find(sections, &(&1.title == "The Optimization Edit"))
    shop = Enum.find(sections, &(&1.title == "Shop My Looks"))

    assert by_section[opt.id] == [{:standard, "Bathhouse"}]
    assert by_section[shop.id] == [{:standard, "Amazon"}]
    assert by_section[support.id] == [{:insta_tip, "Tip Jar"}]
  end

  defp creator_with_recipient! do
    {:ok, %{user: user}} =
      Qlarius.Accounts.register_new_user(%{
        email: "libio-#{System.unique_integer([:positive])}@example.com",
        password: valid_user_password(),
        alias: "libio-user-#{System.unique_integer([:positive])}"
      })

    {:ok, creator} =
      Creators.create_creator(%{
        "name" => "Libio Creator #{System.unique_integer([:positive])}"
      })

    {:ok, _membership} = Creators.create_creator_membership(creator.id, user.id, :owner)
    {:ok, _recipient} = Qlarius.Creators.RecipientProvisioning.ensure_recipient_for_creator(creator)

    Creators.get_creator!(creator.id)
  end
end
