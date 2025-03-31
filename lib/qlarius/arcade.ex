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
end
