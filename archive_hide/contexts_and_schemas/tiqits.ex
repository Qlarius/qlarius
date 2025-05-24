defmodule Qlarius.Tiqits do
  import Ecto.Query

  alias Qlarius.Arcade.Tiqit
  alias Qlarius.Repo

  def list_user_tiqits(user) do
    Repo.all(
      from t in Tiqit,
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        order_by: [desc: t.purchased_at],
        preload: [:tiqit_class, :content_piece]
    )
  end
end
