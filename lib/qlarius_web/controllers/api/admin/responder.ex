defmodule QlariusWeb.Api.Admin.Responder do
  import Plug.Conn
  import Phoenix.Controller

  @guide "/api/admin/agent_guide"

  def guide_path, do: @guide

  def error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(422)
    |> json(%{
      error: "invalid",
      message: "Validation failed",
      errors:
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end),
      guide: @guide
    })
  end

  def error(conn, {:ambiguous_category, candidates}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "ambiguous_category",
      message: "category_name_hint matched more than one category",
      candidates: candidates,
      guide: @guide
    })
  end

  def error(conn, {:ambiguous_survey, candidates}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "ambiguous_survey",
      message: "survey_name_hint matched more than one survey",
      candidates: candidates,
      guide: @guide
    })
  end

  def error(conn, {:invalid_pack, errors}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "invalid_pack",
      message: "The pack has errors. Each entry names the piece index or field to fix.",
      errors: errors,
      guide: @guide
    })
  end

  def error(conn, message) when is_binary(message) do
    conn
    |> put_status(422)
    |> json(%{error: "request_failed", message: message, guide: @guide})
  end

  def error(conn, reason) when is_atom(reason) do
    {status, code, message} = message(reason)

    conn
    |> put_status(status)
    |> json(%{error: code, message: message, guide: @guide})
  end

  defp message(:not_found), do: {404, "not_found", "Not found"}
  defp message(:category_not_found), do: {422, "category_not_found", "Trait category not found"}
  defp message(:survey_not_found), do: {422, "survey_not_found", "Survey not found"}

  defp message(:empty_pack),
    do: {422, "empty_pack", "Design pack needs a non-empty children list"}

  defp message(:invalid_mode), do: {422, "invalid_mode", "mode must be create or reform"}
  defp message(:parent_id_required), do: {422, "parent_id_required", "Reform requires parent.id"}

  defp message(:unexpected_parent_id),
    do: {422, "unexpected_parent_id", "Create must not include parent.id"}

  defp message(:not_a_parent), do: {422, "not_a_parent", "Trait is not a parent"}

  defp message(:protected_parent),
    do: {422, "protected_parent", "Age and zip parents are protected unless force is true"}

  defp message(:multiple_tags),
    do:
      {422, "multiple_tags",
       "A MeFile has multiple tags under this parent; pass force to change input_type"}

  defp message(:invalid_input_type),
    do:
      {422, "invalid_input_type",
       "input_type must be single_select, multi_select, or single_select_zip"}

  defp message(:invalid_trait_name),
    do: {422, "invalid_trait_name", "trait_name is required and must be at most 256 characters"}

  defp message(:child_under_child),
    do: {422, "child_under_child", "Children cannot have children"}

  defp message(:child_not_in_parent),
    do: {422, "child_not_in_parent", "Child does not belong to this parent"}

  defp message(:survey_question_required),
    do: {422, "survey_question_required", "survey_question.text is required"}

  defp message(:invalid_pack_mode),
    do: {422, "invalid_mode", "mode must be create or update"}

  defp message(:empty_content_pack),
    do: {422, "empty_pack", "create needs a non-empty pieces list"}

  defp message(:catalog_not_found),
    do: {422, "catalog_not_found", "catalog_id does not match a catalog"}

  defp message(:content_group_id_required),
    do: {422, "content_group_id_required", "update requires content_group.id"}

  defp message(:unexpected_content_group_id),
    do: {422, "unexpected_content_group_id", "create must not include content_group.id"}

  defp message(:content_group_not_in_catalog),
    do: {422, "content_group_not_in_catalog", "The content group belongs to a different catalog"}

  defp message(:invalid_on_existing),
    do: {422, "invalid_on_existing", "on_existing must be update or skip"}

  defp message(:feed_url_required), do: {422, "feed_url_required", "feed_url is required"}

  defp message(:invalid_season), do: {422, "invalid_season", "season must be an integer"}

  defp message(:invalid_episode_types),
    do: {422, "invalid_episode_types", "episode_types must be a list of full, trailer, and bonus"}

  defp message(:no_feed_url),
    do: {422, "no_feed_url", "This content group has no stored feed_url to sync from"}

  defp message(:unknown_topic),
    do: {404, "unknown_topic", "topic must be content_groups or traits"}

  defp message(:not_admin), do: {403, "forbidden", "Admin role required"}
  defp message(other), do: {422, to_string(other), "Request failed"}
end
