defmodule QlariusWeb.Admin.MeFileTagsIndexController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.MeFiles

  def index(conn, params) do
    me_file_id = resolve_me_file_id(conn, params)
    tag_map = MeFiles.me_file_tag_map_by_category_trait_tag(me_file_id)
    json_string = Jason.encode!(tag_map_to_jsonable(tag_map), pretty: true)

    render(conn, "index.html",
      json_string: json_string,
      me_file_id: me_file_id
    )
  end

  defp resolve_me_file_id(_conn, %{"me_file_id" => id}) when is_binary(id) and id != "" do
    String.to_integer(id)
  end

  defp resolve_me_file_id(conn, _params) do
    conn.assigns.current_scope.user.me_file.id
  end

  defp tag_map_to_jsonable(tag_map) do
    Enum.map(tag_map, fn {{category_id, category_name, category_display_order}, parent_traits} ->
      %{
        "category" => %{
          "id" => category_id,
          "name" => category_name,
          "display_order" => category_display_order
        },
        "parent_traits" =>
          Enum.map(parent_traits, fn {parent_id, parent_name, parent_display_order, tags} ->
            %{
              "id" => parent_id,
              "name" => parent_name,
              "display_order" => parent_display_order,
              "tags" =>
                Enum.map(tags, fn {tag_id, tag_name, tag_display_order} ->
                  %{
                    "id" => tag_id,
                    "name" => tag_name,
                    "display_order" => tag_display_order
                  }
                end)
            }
          end)
      }
    end)
  end
end
