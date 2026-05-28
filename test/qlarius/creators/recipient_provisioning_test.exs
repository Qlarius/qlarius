defmodule Qlarius.Creators.RecipientProvisioningTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Creators
  alias Qlarius.Creators.Creator
  alias Qlarius.Creators.RecipientProvisioning
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient

  import Qlarius.AccountsFixtures, only: [valid_user_password: 0]

  describe "ensure_recipient_for_creator/2" do
    test "creates and links a recipient for a creator with an owner user" do
      user = register_user!()

      {:ok, creator} = Creators.create_creator(%{"name" => "Test Creator"})
      {:ok, _membership} = Creators.create_creator_membership(creator.id, user.id, :owner)

      creator = Repo.get!(Creator, creator.id) |> Repo.preload(:recipient)
      assert is_nil(creator.recipient_id)

      site_url = "https://example.com/tiqit/arqade/1"

      assert {:ok, %Recipient{} = recipient} =
               RecipientProvisioning.ensure_recipient_for_creator(creator, site_url: site_url)

      creator = Repo.get!(Creator, creator.id) |> Repo.preload(:recipient)

      assert creator.recipient_id == recipient.id
      assert recipient.user_id == user.id
      assert recipient.name == "Test Creator"
      assert recipient.site_url == site_url
    end

    test "returns existing recipient when already linked" do
      user = register_user!()

      {:ok, creator} =
        Creators.create_creator_with_user(%{"name" => "Linked Creator"}, user.id)

      creator = Repo.preload(creator, :recipient)
      existing = creator.recipient

      assert {:ok, ^existing} = RecipientProvisioning.ensure_recipient_for_creator(creator)
    end

    test "provisions using platform admin when creator has no owner user" do
      admin = register_user!()
      admin = %{admin | role: "admin"} |> Repo.update!()

      {:ok, creator} = Creators.create_creator(%{"name" => "Orphan Creator"})

      assert {:ok, %Recipient{} = recipient} =
               RecipientProvisioning.ensure_recipient_for_creator(creator)

      assert recipient.user_id == admin.id
      assert Repo.get!(Creator, creator.id).recipient_id == recipient.id
    end
  end

  defp register_user! do
    {:ok, user} =
      Qlarius.Accounts.register_new_user(%{
        email: "recipient-test-#{System.unique_integer()}@example.com",
        password: valid_user_password()
      })

    user
  end
end
