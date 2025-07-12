defmodule Qlarius.Accounts.Marketers do
  alias Qlarius.Repo
  alias Qlarius.Accounts.Marketer
  alias Qlarius.Accounts.Scope

  import Ecto.Query

  def list_marketers(%Scope{} = scope) do
    Repo.all(from m in Marketer)
  end

  def get_marketer!(%Scope{} = scope, id) do
    Repo.get_by!(Marketer, id: id, user_id: scope.user.id)
  end

  def change_marketer(_scope, marketer \\ %Marketer{}) do
    Marketer.changeset(marketer, %{})
  end

  def create_marketer(_scope, attrs) do
    %Marketer{}
    |> Marketer.changeset(attrs)
    |> Repo.insert()
  end

  def update_marketer(_scope, %Marketer{} = marketer, attrs) do
    marketer
    |> Marketer.changeset(attrs)
    |> Repo.update()
  end

  def delete_marketer(_scope, %Marketer{} = marketer) do
    Repo.delete(marketer)
  end
end
