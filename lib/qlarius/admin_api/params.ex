defmodule Qlarius.AdminApi.Params do
  def integer(value) when is_integer(value), do: value

  def integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  def integer(_), do: nil

  def limit(params, default) do
    case integer(params["limit"]) do
      nil -> default
      n when n < 1 -> 1
      n when n > 500 -> 500
      n -> n
    end
  end
end