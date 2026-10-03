defmodule QlariusWeb.Api.Admin.Responder do
  import Plug.Conn
  import Phoenix.Controller

  @guide "/api/admin/agent_guide"

  def guide_path, do: @guide

  def dry_run?(params), do: params["dry_run"] in [true, "true", "1"]

  def error(conn, {:api_ref_conflict, ref}) do
    conn
    |> put_status(409)
    |> json(%{
      error: "api_ref_conflict",
      message:
        "api_ref #{ref} already belongs to a record of another marketer or owner. Stop and ask the admin; do not invent a new key to get around it.",
      api_ref: ref,
      guide: @guide <> "?topic=campaigns"
    })
  end

  def error(conn, {:has_dependents, dependents}) do
    conn
    |> put_status(409)
    |> json(%{
      error: "has_dependents",
      message:
        "This record still has dependent records. Delete or move them first; counts are in dependents.",
      dependents: dependents,
      guide: @guide <> "?topic=campaigns"
    })
  end

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

  def error(conn, {:invalid_rows, errors}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "invalid_rows",
      message: "Some rows have errors. Nothing was saved.",
      errors: errors,
      guide: @guide
    })
  end

  def error(conn, {:in_use, count}) do
    conn
    |> put_status(409)
    |> json(%{
      error: "in_use",
      message: "The row is used by #{count} media piece(s). Remap them or set active to false.",
      media_pieces_count: count,
      guide: @guide
    })
  end

  def error(conn, {:row_inactive, row_id}) do
    conn
    |> put_status(422)
    |> json(%{
      error: "row_inactive",
      message: "Row #{row_id} is inactive and can't receive media pieces",
      row_id: row_id,
      guide: @guide
    })
  end

  def error(conn, {:not_found, row_id}) do
    conn
    |> put_status(404)
    |> json(%{
      error: "not_found",
      message: "Row #{row_id} not found",
      row_id: row_id,
      guide: @guide
    })
  end

  def error(conn, message) when is_binary(message) do
    conn
    |> put_status(422)
    |> json(%{error: "request_failed", message: message, guide: @guide})
  end

  def error(conn, reason) do
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

  defp message(:in_use),
    do: {409, "in_use", "The row is still used by media pieces"}

  defp message(:row_inactive),
    do: {422, "row_inactive", "Inactive rows can't receive media pieces"}

  defp message(:invalid_cohort),
    do:
      {422, "invalid_cohort",
       "cohort must be legacy or YYMMDD-xxxx (date plus 4 lowercase letters or digits)"}

  defp message(:invalid_age),
    do:
      {422, "invalid_age", "age_min must be 18 or 21 when age_gated is true, and blank otherwise"}

  defp message(:unknown_category),
    do: {422, "unknown_category", "Pass an existing category_id or a new_category object"}

  defp message(:immutable_key),
    do: {422, "immutable_key", "row_id and category_id can't be changed"}

  defp message(:selector_required),
    do: {422, "selector_required", "Pass row_ids, category_id, or cohort to choose rows"}

  defp message(:invalid_remap),
    do: {422, "invalid_remap", "Pass mappings, or media_piece_ids with to_row_id"}

  defp message(:unknown_topic),
    do:
      {404, "unknown_topic", "topic must be content_groups, traits, ad_categories, or campaigns"}

  defp message(:api_ref_required),
    do:
      {422, "api_ref_required",
       "Every create needs an api_ref built from the inputs, for example ptp-2610-joes_tacos-phx.marketer. See ?topic=campaigns, section API reference keys."}

  defp message(:invalid_api_ref),
    do:
      {422, "invalid_api_ref",
       "api_ref must be 3 to 128 characters of lowercase letters, digits, '-', '_' or '.', starting with a letter or digit"}

  defp message(:api_ref_immutable),
    do: {422, "api_ref_immutable", "api_ref can't be changed once set"}

  defp message(:image_required),
    do:
      {422, "image_required",
       "A new banner needs image_url (HTTPS) or a multipart banner_image file"}

  defp message(:image_not_https),
    do: {422, "image_not_https", "image_url must be an https URL"}

  defp message(:image_host_blocked),
    do:
      {422, "image_host_blocked",
       "image_url resolves to a private, loopback, or link-local address"}

  defp message(:image_too_large),
    do: {422, "image_too_large", "The image is larger than 10 MB"}

  defp message(:image_type_rejected),
    do: {422, "image_type_rejected", "The image must be JPG, PNG, GIF, or WebP"}

  defp message(:image_redirect_limit),
    do: {422, "image_redirect_limit", "image_url redirected more than 3 times"}

  defp message(:marketer_not_found),
    do: {422, "marketer_not_found", "marketer_id does not match a marketer"}

  defp message(:media_piece_type_not_found),
    do: {422, "media_piece_type_not_found", "media_piece_type_id does not match a type"}

  defp message(:media_piece_type_not_writable),
    do:
      {422, "media_piece_type_not_writable",
       "This media piece type can't be created through the API yet. Use GET /media_piece_types and pick one with writable true."}

  defp message(:owner_required), do: {422, "owner_required", "Send marketer_id or creator_id"}

  defp message(:traits_required),
    do: {422, "traits_required", "A trait group needs at least one trait"}

  defp message({:traits_not_children, missing}),
    do:
      {422, "traits_not_children",
       "These trait ids are not active children of the parent: #{Enum.join(missing, ", ")}"}

  defp message({:frozen_target, ids}),
    do:
      {409, "frozen_target",
       "A launched campaign uses target #{Enum.map_join(ids, ", ", &to_string/1)}. Stop it before changing this."}

  defp message(:trait_group_shared),
    do:
      {409, "trait_group_shared",
       "This group is on more than one target. Create a new group instead of editing this one."}

  defp message(:zip_parent_not_found),
    do:
      {422, "zip_parent_not_found",
       "No active Home Zip Code parent. Pass parent_trait_id to search another zip parent."}

  defp message(:zip_query_too_short),
    do: {422, "zip_query_too_short", "q must be at least 2 characters"}

  defp message(:trait_group_not_found),
    do: {422, "trait_group_not_found", "One or more trait groups were not found"}

  defp message(:trait_group_not_available),
    do:
      {422, "trait_group_not_available", "A trait group is inactive or belongs to another owner"}

  defp message(:drop_not_in_bullseye),
    do: {422, "drop_not_in_bullseye", "drop_order can only list groups that are in the bullseye"}

  defp message(:empty_band), do: {422, "empty_band", "A band would have no trait groups"}

  defp message(:band_drop_mismatch),
    do:
      {422, "band_drop_mismatch",
       "Each outer band must drop exactly one group from the band inside it"}

  defp message(:frozen_target), do: {409, "frozen_target", "A launched campaign uses this target"}

  defp message(:media_piece_required),
    do: {422, "media_piece_required", "media_piece_id and marketer_id are required"}

  defp message(:media_piece_wrong_marketer),
    do: {422, "media_piece_wrong_marketer", "The ad belongs to a different marketer"}

  defp message(:media_piece_inactive), do: {422, "media_piece_inactive", "The ad is not active"}

  defp message(:target_sequence_mismatch),
    do: {422, "target_sequence_mismatch", "The target and sequence belong to different marketers"}

  defp message(:wrong_marketer),
    do: {422, "wrong_marketer", "The target does not belong to marketer_id"}

  defp message(:target_archived), do: {422, "target_archived", "The target is archived"}

  defp message(:sequence_has_no_run),
    do: {422, "sequence_has_no_run", "The sequence has no media run"}

  defp message(:target_has_no_bands), do: {422, "target_has_no_bands", "The target has no bands"}
  defp message(:missing_bids), do: {422, "missing_bids", "Every band needs a bid before launch"}

  defp message(:launched_structure_locked),
    do:
      {409, "launched_structure_locked",
       "target_id and media_sequence_id cannot change after launch"}

  defp message(:confirm_required), do: {422, "confirm_required", "Launch requires confirm: true"}
  defp message(:launched), do: {409, "launched", "A launched campaign cannot be deleted"}
  defp message(:invalid_month), do: {422, "invalid_month", "month must be YYYY-MM"}
  defp message(:title_required), do: {422, "title_required", "title is required"}

  defp message(:ad_category_required),
    do: {422, "ad_category_required", "ad_category_row_id is required"}

  defp message(:invalid_payload),
    do: {422, "invalid_payload", "payload must be a JSON object"}

  defp message(:invalid_trait_groups),
    do: {422, "invalid_trait_groups", "trait_groups must be a list of groups"}

  defp message(:not_admin), do: {403, "forbidden", "Admin role required"}
  defp message({tag, _detail}) when is_atom(tag), do: {422, Atom.to_string(tag), "Request failed"}
  defp message(other) when is_atom(other), do: {422, Atom.to_string(other), "Request failed"}
  defp message(_other), do: {422, "request_failed", "Request failed"}
end
