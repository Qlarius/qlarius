defmodule Qlarius.Sponster.Ads.PublisherCreditTest do
  use ExUnit.Case, async: true

  alias Qlarius.Sponster.Ads.PublisherCredit

  test "a hosted recipient is kept at any split, including 0" do
    recipient = %{id: 7}

    assert PublisherCredit.host(recipient, tip_only?: false) == recipient
    assert PublisherCredit.host(recipient, []) == recipient
    assert PublisherCredit.host_from_jump(recipient, %{}) == recipient
    assert PublisherCredit.host_from_jump(recipient, %{"recipient_id" => "7"}) == recipient
  end

  test "a native tip-only visit drops the host, including autosplit=0" do
    recipient = %{id: 7}

    assert PublisherCredit.host(recipient, tip_only?: true) == nil

    assert PublisherCredit.host_from_jump(recipient, %{"autosplit" => "0", "recipient_id" => "7"}) ==
             nil
  end
end
