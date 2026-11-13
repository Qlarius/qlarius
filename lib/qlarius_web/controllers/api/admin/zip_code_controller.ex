defmodule QlariusWeb.Api.Admin.ZipCodeController do
  use QlariusWeb, :controller

  alias Qlarius.AdminApi.TraitGroups
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    case TraitGroups.search_zips(params["q"], params["parent_trait_id"]) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def lookup(conn, params) do
    case TraitGroups.lookup_zips(params["parent_trait_id"], params["zips"]) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end
end
