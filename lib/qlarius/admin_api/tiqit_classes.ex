defmodule Qlarius.AdminApi.TiqitClasses do
  @moduledoc """
  Read-only tiqit classes. Prices are changed in the admin UI.
  """

  import Ecto.Query

  alias Qlarius.AdminApi.Params
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.TiqitClass

  def list(params) do
    filters =
      [
        catalog_id: Params.integer(params["catalog_id"]),
        content_group_id: Params.integer(params["content_group_id"]),
        content_piece_id: Params.integer(params["content_piece_id"])
      ]
      |> Enum.reject(fn {_key, id} -> is_nil(id) end)

    if filters == [] do
      {:error, :tiqit_class_scope_required}
    else
      classes =
        Enum.reduce(filters, TiqitClass, fn {field, id}, query ->
          where(query, [t], field(t, ^field) == ^id)
        end)
        |> order_by([t], asc: t.duration_hours, asc: t.id)
        |> Repo.all()

      {:ok, classes}
    end
  end
end