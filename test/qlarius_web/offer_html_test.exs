defmodule QlariusWeb.OfferHTMLTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.OfferHTML

  defmodule FakeOffer do
    defstruct [:id]
  end

  defmodule FakeRecipient do
    defstruct [:id]
  end

  test "jump_url includes a parseable recipient_id query param" do
    url = OfferHTML.jump_url(%FakeOffer{id: 42}, %FakeRecipient{id: 99})

    assert %URI{query: query} = URI.parse(url)
    assert %{"recipient_id" => "99"} = URI.decode_query(query)
    refute String.contains?(url, "recipient_id%3D")
  end

  test "jump_url tip_only keeps autosplit=0 parseable" do
    url =
      OfferHTML.jump_url(%FakeOffer{id: 42}, %FakeRecipient{id: 99}, tip_only: true)

    assert %URI{query: query} = URI.parse(url)
    assert %{"recipient_id" => "99", "autosplit" => "0"} = URI.decode_query(query)
  end

  test "jump_url without recipient has no query" do
    url = OfferHTML.jump_url(%FakeOffer{id: 42}, nil)
    assert url == "/jump/42"
  end
end
