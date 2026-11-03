defmodule QlariusWeb.Helpers.ImageHelpersTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Helpers.ImageHelpers
  alias QlariusWeb.Uploaders.RecipientBrandImage

  describe "recipient_brand_image_url/2" do
    test "uses the recipient brand image" do
      recipient = %Recipient{
        id: 1,
        graphic_url: %{file_name: "thank-you.png", updated_at: nil}
      }

      assert ImageHelpers.recipient_brand_image_url(recipient) ==
               RecipientBrandImage.url({recipient.graphic_url, recipient})
    end

    test "uses the tip jar default when the recipient has no brand image" do
      recipient = %Recipient{id: 1, graphic_url: nil}

      url = ImageHelpers.recipient_brand_image_url(recipient, creator: %{image: "creator-face.png"})

      assert url == RecipientBrandImage.url({nil, recipient})
      assert url =~ "tipjar_love_default.png"
      refute url =~ "creator-face.png"
    end
  end
end
