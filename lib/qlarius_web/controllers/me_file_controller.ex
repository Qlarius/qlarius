defmodule QlariusWeb.MeFileController do
  use QlariusWeb, :controller

  alias Qlarius.MeFile

  def surveys(conn, _params) do
    user = conn.assigns.current_user

    categories = MeFile.list_survey_categories_with_stats(user.id)
    trait_count = MeFile.count_traits_with_values(user.id)
    tag_count = MeFile.count_user_tags(user.id)

    render(conn, :surveys,
      categories: categories,
      trait_count: trait_count,
      tag_count: tag_count
    )
  end
end
