defmodule QlariusWeb.Helpers.ImageHelpersTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Creators
  alias Qlarius.Creators.RecipientProvisioning
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.Uploaders.CreatorImage

  import Qlarius.AccountsFixtures, only: [valid_user_password: 0]

  describe "recipient_brand_image_url/2" do
    test "uses creator image when recipient has no brand image" do
      user = register_user!()

      {:ok, creator} =
        Creators.create_creator_with_user(
          %{"name" => "Branded Creator", "image" => "creator-brand.jpg"},
          user.id
        )

      creator = Repo.preload(creator, :recipient)
      recipient = creator.recipient

      assert %Recipient{graphic_url: nil} = recipient

      assert ImageHelpers.recipient_brand_image_url(recipient, creator: creator) ==
               CreatorImage.url({creator.image, creator}, :original)
    end

    test "looks up creator by recipient_id when creator is not passed" do
      user = register_user!()

      {:ok, creator} =
        Creators.create_creator_with_user(
          %{"name" => "Lookup Creator", "image" => "lookup-brand.jpg"},
          user.id
        )

      recipient = Repo.preload(creator, :recipient).recipient

      assert ImageHelpers.recipient_brand_image_url(recipient) ==
               CreatorImage.url({creator.image, creator}, :original)
    end

    test "returns placeholder when recipient and creator have no images" do
      {:ok, creator} = Creators.create_creator(%{"name" => "No Image Creator"})
      assert {:ok, recipient} = RecipientProvisioning.ensure_recipient_for_creator(creator)

      assert ImageHelpers.recipient_brand_image_url(recipient) ==
               ImageHelpers.placeholder_image_url()
    end
  end

  defp register_user! do
    {:ok, user} =
      Qlarius.Accounts.register_new_user(%{
        email: "image-helper-#{System.unique_integer()}@example.com",
        password: valid_user_password()
      })

    user
  end
end
