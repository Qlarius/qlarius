defmodule QlariusWeb.Helpers.ImageHelpersTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.Uploaders.RecipientBrandImage

  describe "recipient_brand_image_url/2" do
    test "uses the recipient brand image ahead of the creator image" do
      creator = %Creator{id: 9, image: "creator-face.png"}

      recipient = %Recipient{
        id: 1,
        creator_id: creator.id,
        graphic_url: %{file_name: "thank-you.png", updated_at: nil}
      }

      assert ImageHelpers.recipient_brand_image_url(recipient, creator: creator) ==
               RecipientBrandImage.url({recipient.graphic_url, recipient})
    end

    test "uses the passed creator image when the recipient has no brand image" do
      creator = %Creator{id: 9, image: "creator-face.png"}
      recipient = %Recipient{id: 1, creator_id: creator.id, graphic_url: nil}

      assert ImageHelpers.recipient_brand_image_url(recipient, creator: creator) ==
               CreatorImage.url({creator.image, creator}, :original)
    end

    test "loads the associated creator image when none is passed" do
      {:ok, creator} =
        %Creator{}
        |> Creator.changeset(%{"name" => "Zach"})
        |> Ecto.Changeset.change(%{image: "zach.png"})
        |> Repo.insert()

      owner =
        Repo.insert!(%Qlarius.Accounts.User{
          alias: "brand-owner-#{System.unique_integer([:positive])}"
        })

      recipient =
        Repo.insert!(%Recipient{
          user_id: owner.id,
          creator_id: creator.id,
          name: "Zach Allen",
          split_code: Ecto.UUID.generate(),
          referral_code: "brand-#{System.unique_integer([:positive])}",
          site_url: "https://zach.example"
        })

      assert ImageHelpers.recipient_brand_image_url(recipient) ==
               CreatorImage.url({"zach.png", creator}, :original)
    end

    test "uses the tip jar default when neither the recipient nor a creator has an image" do
      recipient = %Recipient{id: 1, graphic_url: nil}

      url = ImageHelpers.recipient_brand_image_url(recipient)

      assert url == RecipientBrandImage.url({nil, recipient})
      assert url =~ "tipjar_love_default.png"
    end
  end
end
