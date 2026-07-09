defmodule Qlarius.MeCP.Oracle do
  @moduledoc """
  Narrow question answering against grants, with disclosure budgets.

  v1 accepts **structured question forms only** (free-text NL questions come
  post-Phase-1 and will need an LLM pass). Questions target *effective* traits
  (a child trait id is resolved to its parent):

    * `{:has_trait, trait_id}` — boolean: does the MeFile hold any value for
      this trait?
    * `{:trait_values, trait_id}` — the trait's values, each with its
      confirmation month/year.
    * `{:value_in, trait_id, values}` — boolean: is any of the MeFile's values
      for this trait in `values`? (case-insensitive)
    * `{:bucket, trait_id, buckets}` — the label of the first bucket
      (`{label, values}`) containing one of the MeFile's values, or `nil`.
      Discloses the bucket label only, never the value.

  Split like `Capsules`: `answer/2` is a **pure function over a built capsule**
  (so scope containment is inherited from the capsule build), while `ask/3`
  is the stateful gateway that checks the grant (tier, expiry, revocation),
  enforces the per-period disclosure budget, resolves scope, and writes exactly
  one access-log row per answered question.
  """

  alias Qlarius.MeCP.AccessLog
  alias Qlarius.MeCP.Capsules
  alias Qlarius.MeCP.Capsules.{Capsule, Scope}
  alias Qlarius.MeCP.Grants
  alias Qlarius.MeCP.Grants.Grant
  alias Qlarius.Repo
  alias Qlarius.YouData.Traits.Trait

  @type question ::
          {:has_trait, integer()}
          | {:trait_values, integer()}
          | {:value_in, integer(), [String.t()]}
          | {:bucket, integer(), [{String.t(), [String.t()]}]}

  # --- stateful gateway -----------------------------------------------------

  @doc """
  Answers a structured question under a grant.

  Checks tier (oracle requires tier >= 2), revocation, expiry, scope, and the
  per-period disclosure budget; on success writes one `oracle` access event and
  returns `{:ok, answer}`.

  Errors: `:revoked | :expired | :insufficient_tier | :budget_exhausted |
  :unsupported_question | :unknown_trait | :out_of_scope`.

  Options: `:now` (DateTime, for tests), `:terms_agreement_id`.
  """
  @spec ask(Grant.t(), question(), keyword()) :: {:ok, term()} | {:error, atom()}
  def ask(%Grant{} = grant, question, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    scope = Grants.scope(grant)

    with :ok <- Grants.check(grant, :oracle, now),
         :ok <- Grants.check_budget(grant, now),
         {:ok, trait_id} <- question_trait_id(question),
         {:ok, trait_ref} <- effective_trait_ref(trait_id),
         :ok <- check_scope(scope, trait_ref),
         {:ok, answer} <- answer(build_capsule(grant, scope), retarget(question, trait_ref)) do
      AccessLog.record!(
        grant,
        "oracle",
        AccessLog.digest(question),
        response_shape(question, answer),
        occurred_at: now,
        terms_agreement_id: Keyword.get(opts, :terms_agreement_id)
      )

      {:ok, answer}
    end
  end

  # --- pure answer core -----------------------------------------------------

  @doc """
  Answers a question against a built (already scoped) capsule. Pure.

  Never returns an out-of-scope disclosure: the capsule was built under the
  grant's scope, so out-of-scope traits simply aren't present here (the `ask/3`
  wrapper distinguishes out-of-scope from no-data before calling this).
  """
  @spec answer(Capsule.t(), question()) :: {:ok, term()} | {:error, :unsupported_question}
  def answer(%Capsule{} = capsule, {:has_trait, trait_id}) do
    {:ok, find_values(capsule, trait_id) != []}
  end

  def answer(%Capsule{} = capsule, {:trait_values, trait_id}) do
    values =
      for v <- find_values(capsule, trait_id) do
        %{value: v.text, confirmed: format_date(v.added_date)}
      end

    {:ok, values}
  end

  def answer(%Capsule{} = capsule, {:value_in, trait_id, candidates}) when is_list(candidates) do
    candidate_set = MapSet.new(candidates, &normalize/1)
    held = find_values(capsule, trait_id)
    {:ok, Enum.any?(held, fn v -> MapSet.member?(candidate_set, normalize(v.text)) end)}
  end

  def answer(%Capsule{} = capsule, {:bucket, trait_id, buckets}) when is_list(buckets) do
    held = MapSet.new(find_values(capsule, trait_id), &normalize(&1.text))

    label =
      Enum.find_value(buckets, fn {label, values} ->
        if Enum.any?(values, &MapSet.member?(held, normalize(&1))), do: label
      end)

    {:ok, label}
  end

  def answer(%Capsule{}, _question), do: {:error, :unsupported_question}

  # --- helpers --------------------------------------------------------------

  defp question_trait_id({:has_trait, id}) when is_integer(id), do: {:ok, id}
  defp question_trait_id({:trait_values, id}) when is_integer(id), do: {:ok, id}

  defp question_trait_id({:value_in, id, values}) when is_integer(id) and is_list(values),
    do: {:ok, id}

  defp question_trait_id({:bucket, id, buckets}) when is_integer(id) and is_list(buckets),
    do: {:ok, id}

  defp question_trait_id(_), do: {:error, :unsupported_question}

  # Resolves a question's trait id to its effective trait (parent if the id
  # names a child) so scope checks and capsule lookups agree with how
  # capsules group data.
  defp effective_trait_ref(trait_id) do
    case Repo.get(Trait, trait_id) do
      nil ->
        {:error, :unknown_trait}

      %Trait{parent_trait_id: nil} = trait ->
        {:ok, %{trait_id: trait.id, category_key: trait.trait_category_id}}

      %Trait{parent_trait_id: parent_id} ->
        parent = Repo.get!(Trait, parent_id)
        {:ok, %{trait_id: parent.id, category_key: parent.trait_category_id}}
    end
  end

  defp check_scope(%Scope{} = scope, trait_ref) do
    if Scope.allows?(scope, trait_ref), do: :ok, else: {:error, :out_of_scope}
  end

  defp build_capsule(%Grant{} = grant, %Scope{} = scope) do
    grant.me_file_id
    |> Qlarius.MeCP.load_me_file()
    |> Capsules.build(scope)
  end

  # Rewrites the question to target the effective trait id.
  defp retarget({:has_trait, _}, %{trait_id: id}), do: {:has_trait, id}
  defp retarget({:trait_values, _}, %{trait_id: id}), do: {:trait_values, id}
  defp retarget({:value_in, _, values}, %{trait_id: id}), do: {:value_in, id, values}
  defp retarget({:bucket, _, buckets}, %{trait_id: id}), do: {:bucket, id, buckets}

  defp find_values(%Capsule{categories: categories}, trait_id) do
    Enum.find_value(categories, [], fn category ->
      Enum.find_value(category.traits, nil, fn trait ->
        if trait.id == trait_id, do: trait.values
      end)
    end)
  end

  defp normalize(text), do: text |> String.trim() |> String.downcase()

  defp format_date(nil), do: nil
  defp format_date(date), do: Calendar.strftime(date, "%b %Y")

  # The audit row records what was asked and the *shape* of the answer,
  # never values, booleans, or bucket labels.
  defp response_shape({form, trait_id}, answer), do: base_shape(form, trait_id, answer)
  defp response_shape({form, trait_id, _arg}, answer), do: base_shape(form, trait_id, answer)

  defp base_shape(form, trait_id, answer) do
    %{
      "form" => Atom.to_string(form),
      "trait_id" => trait_id,
      "answer_type" => answer_type(answer),
      "answer_size" => answer_size(answer)
    }
  end

  defp answer_type(answer) when is_boolean(answer), do: "boolean"
  defp answer_type(answer) when is_list(answer), do: "value_list"
  defp answer_type(nil), do: "no_bucket"
  defp answer_type(answer) when is_binary(answer), do: "bucket"

  defp answer_size(answer) when is_list(answer), do: length(answer)
  defp answer_size(_), do: 1
end
