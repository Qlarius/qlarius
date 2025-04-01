defmodule Qlarius.Arcade do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Arcade.Content
  alias Qlarius.Arcade.TiqitType

  def list_content do
    Repo.all(
      from c in Content,
        order_by: [desc: c.inserted_at],
        limit: 5,
        preload: [tiqit_types: ^from(t in TiqitType, order_by: t.price)]
    )
  end

  def get_content!(id), do: Repo.get!(Content, id)

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
end
