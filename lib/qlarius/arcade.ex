defmodule Qlarius.Arcade do
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.Arcade.Content
  alias Qlarius.Arcade.Tiqit
  alias Qlarius.Arcade.TiqitType
  alias Qlarius.Repo

  def has_valid_tiqit?(%Content{} = content, %User{} = user) do
    now = DateTime.utc_now()

    query =
      from t in Tiqit,
        join: tt in TiqitType,
        on: t.tiqit_type_id == tt.id,
        where: tt.content_id == ^content.id,
        where: t.user_id == ^user.id,
        where: is_nil(t.expires_at) or t.expires_at > ^now

    Repo.exists?(query)
  end

  def list_content do
    Repo.all(
      from c in Content,
        order_by: [desc: c.inserted_at],
        limit: 5,
        preload: [tiqit_types: ^from(t in TiqitType, order_by: t.price)]
    )
  end

  def get_content!(id), do: Content |> Repo.get!(id) |> Repo.preload(:tiqit_types)

  def create_content(attrs \\ %{}) do
    %Content{}
    |> Content.changeset(attrs)
    |> Repo.insert()
  end

  def update_content(%Content{} = content, attrs) do
    content
    |> Content.changeset(attrs)
    |> Repo.update()
  end

  def delete_content(%Content{} = content) do
    Repo.delete(content)
  end

  def change_content(%Content{} = content, attrs \\ %{}) do
    Content.changeset(content, attrs)
  end

  def create_tiqit(%User{} = user, %TiqitType{} = tiqit_type) do
    purchased_at = DateTime.utc_now()

    expires_at =
      if tiqit_type.duration_seconds > 0 do
        DateTime.add(purchased_at, tiqit_type.duration_seconds, :second)
      end

    %Tiqit{user: user, tiqit_type: tiqit_type}
    |> Tiqit.changeset(%{purchased_at: purchased_at, expires_at: expires_at})
    |> Repo.insert()
  end
end
