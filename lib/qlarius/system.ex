defmodule Qlarius.System do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.System.GlobalVariable

  def get_global_variable(name, default \\ nil) do
    case Repo.get_by(GlobalVariable, name: name) do
      %GlobalVariable{value: value} when not is_nil(value) -> value
      _ -> default
    end
  end

  def get_global_variable_int(name, default \\ 0) do
    case get_global_variable(name) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  def set_global_variable(name, value) do
    case Repo.get_by(GlobalVariable, name: name) do
      nil ->
        %GlobalVariable{}
        |> GlobalVariable.changeset(%{name: name, value: to_string(value)})
        |> Repo.insert()

      existing ->
        existing
        |> GlobalVariable.changeset(%{value: to_string(value)})
        |> Repo.update()
    end
  end

  def list_global_variables do
    Repo.all(from gv in GlobalVariable, order_by: gv.name)
  end
end
