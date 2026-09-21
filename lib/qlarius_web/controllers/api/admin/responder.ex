defmodule QlariusWeb.Api.Admin.Responder do
  import Plug.Conn
  import Phoenix.Controller

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
        end)
    })
  end

  def error(conn, {:ambiguous_category, candidates}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "ambiguous_category",
      message: "category_name_hint matched more than one category",
      candidates: candidates
    })
  end

  def error(conn, {:ambiguous_survey, candidates}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "ambiguous_survey",
      message: "survey_name_hint matched more than one survey",
      candidates: candidates
    })
  end

  def error(conn, reason) when is_atom(reason) do
    {status, code, message} = message(reason)

    conn
    |> put_status(status)
    |> json(%{error: code, message: message})
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

  defp message(:not_admin), do: {403, "forbidden", "Admin role required"}
  defp message(other), do: {422, to_string(other), "Request failed"}
end
