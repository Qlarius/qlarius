defmodule QlariusWeb.MeFileController do
  use QlariusWeb, :controller

  alias Qlarius.Surveys
  alias Qlarius.Traits

  def surveys(conn, _params) do
    user = conn.assigns.current_scope.user

    categories = Surveys.list_survey_categories_with_stats(user.id)
    trait_count = Traits.count_traits_with_values(user.id)
    tag_count = Traits.count_me_file_tags(user.me_file.id)

    render(conn, :surveys,
      categories: categories,
      trait_count: trait_count,
      tag_count: tag_count
    )
  end
end
