defmodule Qlarius.Arcade do
  import Ecto.Query

  alias Qlarius.Accounts.Scope
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.Tiqit
  alias Qlarius.Arcade.TiqitType
  alias Qlarius.Repo

  def has_valid_tiqit?(%Scope{} = scope, %ContentPiece{} = content) do
    now = DateTime.utc_now()

    query =
      from t in Tiqit,
        join: tt in TiqitType,
        on: t.tiqit_type_id == tt.id,
        where: tt.content_piece_id == ^content.id,
        where: t.user_id == ^scope.user.id,
        where: is_nil(t.expires_at) or t.expires_at > ^now

    Repo.exists?(query)
  end

  def list_content_groups do
    Repo.all(from g in ContentGroup, order_by: [asc: g.title])
  end

  def get_content_group!(id) do
    Repo.get!(ContentGroup, id) |> Repo.preload(content_pieces: :tiqit_types)
  end

  def list_pieces_in_content_group(%ContentGroup{} = group) do
    Repo.all(
      from c in ContentPiece,
        where: c.group_id == ^group.id,
        order_by: [desc: c.inserted_at],
        limit: 5,
        preload: [tiqit_types: ^from(t in TiqitType, order_by: t.price)]
    )
  end

  def get_content_piece!(id) do
    ContentPiece |> Repo.get!(id) |> Repo.preload(:tiqit_types)
  end

  def create_content(attrs \\ %{}) do
    %ContentPiece{}
    |> ContentPiece.changeset(attrs)
    |> Repo.insert()
  end

  def update_content(%ContentPiece{} = content, attrs) do
    content
    |> ContentPiece.changeset(attrs)
    |> Repo.update()
  end

  def delete_content(%ContentPiece{} = content) do
    Repo.delete(content)
  end

  def change_content(%ContentPiece{} = content, attrs \\ %{}) do
    ContentPiece.changeset(content, attrs)
  end

  def create_tiqit(%Scope{} = scope, %TiqitType{} = tiqit_type) do
    purchased_at = DateTime.utc_now()

    expires_at =
      if tiqit_type.duration_seconds do
        DateTime.add(purchased_at, tiqit_type.duration_seconds, :second)
      end

    %Tiqit{user: scope.user, tiqit_type: tiqit_type}
    |> Tiqit.changeset(%{purchased_at: purchased_at, expires_at: expires_at})
    |> Repo.insert()
  end
end
