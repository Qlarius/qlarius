defmodule Qlarius.YouData.TraitDesign do
  @moduledoc """
  Creates or reforms a parent trait, its children, and the linked survey
  question and answers in one transaction.

  After a pack, active sibling `display_order` values are restriped to 1..N
  in the order requested (name, then id, breaks ties). Omitted children are
  soft-deactivated only when `deactivate_missing_children` is true. MeFile
  tags on those children are left in place.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.SurveyManager
  alias Qlarius.YouData.Surveys.Survey
  alias Qlarius.YouData.TraitGuards
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitCategory

  def apply(scope, params) when is_map(params) do
    mode = params["mode"]
    parent_params = params["parent"] || %{}
    children = params["children"]
    force = truthy?(params["force"])

    cond do
      mode not in ["create", "reform"] ->
        {:error, :invalid_mode}

      not is_list(children) or children == [] ->
        {:error, :empty_pack}

      mode == "reform" and is_nil(integer(parent_params["id"])) ->
        {:error, :parent_id_required}

      mode == "create" and not is_nil(parent_params["id"]) ->
        {:error, :unexpected_parent_id}

      true ->
        Repo.transaction(fn ->
          case do_apply(scope, mode, parent_params, children, params, force) do
            {:ok, detail} -> detail
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
    end
  end

  defp do_apply(scope, mode, parent_params, children, params, force) do
    with {:ok, category_id} <- resolve_category(parent_params),
         {:ok, parent} <- load_or_build(scope, mode, parent_params, category_id),
         :ok <- guard(parent, mode, parent_params, force),
         {:ok, parent} <- save_parent(scope, mode, parent, parent_params, category_id),
         {:ok, child_traits} <- upsert_children(scope, parent, children),
         {:ok, deactivated_ids} <-
           deactivate_missing(scope, parent, child_traits, params),
         {:ok, question} <- upsert_question(scope, parent, params["survey_question"]),
         :ok <- upsert_answers(scope, question, child_traits, children),
         :ok <- attach_survey(scope, question, params["attach_to_survey"]),
         {:ok, _} <- TraitManager.restripe_active_children(scope, parent) do
      detail =
        parent.id
        |> then(&TraitManager.get_parent_trait_with_details(scope, &1))
        |> parent_detail()
        |> Map.put(:deactivated_child_ids, deactivated_ids)
        |> Map.put(:deactivated_tag_count, TraitGuards.tag_count(deactivated_ids))

      {:ok, detail}
    end
  end

  defp guard(%Trait{} = existing, "reform", params, force) do
    new_type = params["input_type"]

    with :ok <- TraitGuards.ensure_child_mutation(existing, force),
         :ok <- TraitGuards.ensure_input_type_change(existing, new_type, force) do
      :ok
    end
  end

  defp guard(_parent, "create", params, force) do
    type = params["input_type"]

    cond do
      type not in TraitGuards.input_types() ->
        {:error, :invalid_input_type}

      type == "single_select_zip" and not force ->
        {:error, :protected_parent}

      blank?(params["trait_name"]) or String.length(string(params["trait_name"])) > 256 ->
        {:error, :invalid_trait_name}

      true ->
        :ok
    end
  end

  defp load_or_build(_scope, "create", _params, _category_id), do: {:ok, nil}

  defp load_or_build(_scope, "reform", params, _category_id) do
    case Repo.get(Trait, integer(params["id"])) do
      nil ->
        {:error, :not_found}

      %Trait{parent_trait_id: id} when not is_nil(id) ->
        {:error, :not_a_parent}

      parent ->
        {:ok, parent}
    end
  end

  defp save_parent(scope, "create", _parent, params, category_id) do
    category_id = if category_id == :omit, do: nil, else: category_id

    TraitManager.create_parent_trait(
      scope,
      %{
        "trait_name" => string(params["trait_name"]),
        "input_type" => params["input_type"],
        "trait_category_id" => category_id,
        "display_order" => integer(params["display_order"]),
        "is_active" => active_flag(params, true)
      },
      keep_display_order: is_integer(integer(params["display_order"])),
      keep_active: true
    )
  end

  defp save_parent(scope, "reform", parent, params, category_id) do
    attrs = %{"modified_by" => scope.true_user.id}

    attrs =
      if blank?(params["trait_name"]),
        do: attrs,
        else: Map.put(attrs, "trait_name", string(params["trait_name"]))

    attrs =
      if params["input_type"] in [nil, ""],
        do: attrs,
        else: Map.put(attrs, "input_type", params["input_type"])

    attrs =
      if is_integer(integer(params["display_order"])),
        do: Map.put(attrs, "display_order", integer(params["display_order"])),
        else: attrs

    attrs =
      if Map.has_key?(params, "is_active"),
        do: Map.put(attrs, "is_active", truthy?(params["is_active"])),
        else: attrs

    attrs =
      cond do
        category_id == :omit -> attrs
        true -> Map.put(attrs, "trait_category_id", category_id)
      end

    TraitManager.update_parent_trait(scope, parent, attrs)
  end

  defp upsert_children(scope, parent, children) do
    parent = Repo.get!(Trait, parent.id)

    Enum.reduce_while(children, {:ok, []}, fn child_params, {:ok, acc} ->
      case upsert_child(scope, parent, child_params) do
        {:ok, child} -> {:cont, {:ok, acc ++ [child]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp upsert_child(scope, parent, params) do
    name = params["trait_name"]

    cond do
      not blank?(name) and String.length(string(name)) > 256 ->
        {:error, :invalid_trait_name}

      true ->
        case integer(params["id"]) do
          nil ->
            if blank?(name) do
              {:error, :invalid_trait_name}
            else
              TraitManager.create_child_trait(scope, parent, %{
                "trait_name" => string(name),
                "display_order" => integer(params["display_order"]),
                "is_active" => active_flag(params, true)
              })
            end

          id ->
            case Repo.get(Trait, id) do
              %Trait{parent_trait_id: parent_id} = child when parent_id == parent.id ->
                attrs = %{"is_active" => active_flag(params, true)}

                attrs =
                  if blank?(name), do: attrs, else: Map.put(attrs, "trait_name", string(name))

                attrs =
                  if is_integer(integer(params["display_order"])),
                    do: Map.put(attrs, "display_order", integer(params["display_order"])),
                    else: attrs

                TraitManager.update_child_trait(scope, child, attrs)

              _ ->
                {:error, :child_not_in_parent}
            end
        end
    end
  end

  defp deactivate_missing(scope, parent, kept, params) do
    if truthy?(params["deactivate_missing_children"]) do
      kept_ids = MapSet.new(Enum.map(kept, & &1.id))

      stale_ids =
        Repo.all(
          from t in Trait,
            where: t.parent_trait_id == ^parent.id and t.is_active == true,
            select: t.id
        )
        |> Enum.reject(&MapSet.member?(kept_ids, &1))

      Enum.each(stale_ids, fn id ->
        trait = Repo.get!(Trait, id)
        {:ok, _} = TraitManager.deactivate_trait(scope, trait)
      end)

      {:ok, stale_ids}
    else
      {:ok, []}
    end
  end

  defp upsert_question(_scope, _parent, question) when question in [nil, %{}] do
    {:error, :survey_question_required}
  end

  defp upsert_question(scope, parent, %{"text" => text}) do
    text = string(text)

    if blank?(text) do
      {:error, :survey_question_required}
    else
      parent = Repo.get!(Trait, parent.id)
      TraitManager.ensure_survey_question(scope, parent, text)
    end
  end

  defp upsert_answers(scope, question, child_traits, child_params) do
    question = unwrap_question(question)

    Enum.zip(child_traits, child_params)
    |> Enum.reduce_while(:ok, fn {child, params}, :ok ->
      child = Repo.get!(Trait, child.id)

      case TraitManager.ensure_survey_answer(scope, question, child, params["survey_answer_text"]) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp unwrap_question({:ok, question}), do: question
  defp unwrap_question(question), do: question

  defp attach_survey(_scope, _question, attach) when attach in [nil, %{}], do: :ok

  defp attach_survey(scope, question, attach) do
    question = unwrap_question(question)

    with {:ok, survey_id} <- resolve_survey(attach) do
      case survey_id do
        nil ->
          :ok

        id ->
          case SurveyManager.place_question(
                 scope,
                 id,
                 question.id,
                 integer(attach["display_order"])
               ) do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  defp resolve_category(params) do
    id = integer(params["trait_category_id"])
    hint = params["category_name_hint"]

    cond do
      is_integer(id) ->
        if Repo.get(TraitCategory, id), do: {:ok, id}, else: {:error, :category_not_found}

      is_binary(hint) and String.trim(hint) != "" ->
        hint = String.trim(hint)

        case Repo.all(from c in TraitCategory, where: ilike(c.name, ^hint)) do
          [category] ->
            {:ok, category.id}

          [] ->
            {:error, :category_not_found}

          many ->
            {:error, {:ambiguous_category, Enum.map(many, &%{id: &1.id, name: &1.name})}}
        end

      Map.has_key?(params, "trait_category_id") ->
        {:ok, nil}

      true ->
        {:ok, :omit}
    end
  end

  defp resolve_survey(attach) do
    id = integer(attach["survey_id"])
    hint = attach["survey_name_hint"]

    cond do
      is_integer(id) ->
        if Repo.get(Survey, id), do: {:ok, id}, else: {:error, :survey_not_found}

      is_binary(hint) and String.trim(hint) != "" ->
        hint = String.trim(hint)

        case Repo.all(from s in Survey, where: ilike(s.name, ^hint)) do
          [survey] ->
            {:ok, survey.id}

          [] ->
            {:error, :survey_not_found}

          many ->
            {:error, {:ambiguous_survey, Enum.map(many, &%{id: &1.id, name: &1.name})}}
        end

      true ->
        {:ok, nil}
    end
  end

  def parent_detail(parent) do
    %{
      id: parent.id,
      trait_name: parent.trait_name,
      input_type: parent.input_type,
      is_active: parent.is_active,
      display_order: parent.display_order,
      trait_category_id: parent.trait_category_id,
      survey_question: question_json(Map.get(parent, :survey_question)),
      children: Enum.map(parent.child_traits || [], &child_json/1),
      child_traits_count: Map.get(parent, :child_traits_count)
    }
  end

  defp question_json(nil), do: nil

  defp question_json(question) do
    %{id: question.id, text: question.text}
  end

  defp child_json(child) do
    answer = Map.get(child, :survey_answer)

    %{
      id: child.id,
      trait_name: child.trait_name,
      display_order: child.display_order,
      is_active: child.is_active,
      me_file_tag_count: Map.get(child, :tags_count, 0),
      survey_answer: answer_json(answer)
    }
  end

  defp answer_json(nil), do: nil
  defp answer_json(answer), do: %{id: answer.id, text: answer.text}

  defp active_flag(params, default) do
    if Map.has_key?(params, "is_active"), do: truthy?(params["is_active"]), else: default
  end

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil

  defp string(value) when is_binary(value), do: String.trim(value)
  defp string(_), do: ""

  defp blank?(value), do: value in [nil, ""] or (is_binary(value) and String.trim(value) == "")
end
