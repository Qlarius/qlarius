defmodule Qlarius.Sponster.Recipients do
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient

  def list_recipients do
    Repo.all(Recipient)
  end

  def get_recipient!(id) do
    Repo.get!(Recipient, id)
  end

  def create_recipient(attrs \\ %{}) do
    attrs =
      Map.put_new(attrs, :referral_code, Qlarius.Referrals.generate_referral_code("recipient"))

    %Recipient{}
    |> Recipient.changeset(attrs)
    |> Repo.insert()
  end

  def update_recipient(%Recipient{} = recipient, attrs) do
    recipient
    |> Recipient.changeset(attrs)
    |> Repo.update()
  end

  def delete_recipient(%Recipient{} = recipient) do
    Repo.delete(recipient)
  end

  def change_recipient(%Recipient{} = recipient, attrs \\ %{}) do
    Recipient.changeset(recipient, attrs)
  end
end
