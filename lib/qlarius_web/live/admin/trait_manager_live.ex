defmodule QlariusWeb.Admin.TraitManagerLive do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Surveys.{SurveyQuestion, SurveyAnswer}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Trait Manager")
     |> assign(:search_query, "")
     |> assign(:parent_traits, TraitManager.list_parent_traits(scope, ""))
     |> assign(:trait_categories, TraitManager.list_trait_categories(scope))
     |> assign(:selected_parent_trait, nil)
     |> assign(:editor_mode, nil)
     |> assign(:editing_item, nil)
     |> assign(:form, nil)
     |> assign(:batch_traits_text, "")
     |> assign(:can_delete_parent, false)}
  end

  def handle_event("search", %{"search" => search_query}, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:parent_traits, TraitManager.list_parent_traits(scope, search_query))}
  end

  def handle_event("clear_search", _params, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:parent_traits, TraitManager.list_parent_traits(scope, ""))}
  end

  def handle_event("select_parent", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    parent_trait = TraitManager.get_parent_trait_with_details(scope, id)

    {:noreply,
     socket
     |> assign(:selected_parent_trait, parent_trait)
     |> assign(:editor_mode, nil)
     |> assign(:editing_item, nil)
     |> assign(:form, nil)}
  end

  def handle_event("new_parent_trait", _params, socket) do
    changeset = Trait.changeset(%Trait{}, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :new_parent)
     |> assign(:editing_item, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("edit_parent_trait", _params, socket) do
    parent_trait = socket.assigns.selected_parent_trait
    changeset = Trait.changeset(parent_trait, %{})

    can_delete = TraitManager.can_delete_trait?(parent_trait)

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_parent)
     |> assign(:editing_item, parent_trait)
     |> assign(:can_delete_parent, can_delete)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save_parent_trait", %{"trait" => trait_params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.editor_mode do
        :new_parent ->
          TraitManager.create_parent_trait(scope, trait_params)

        :edit_parent ->
          TraitManager.update_parent_trait(scope, socket.assigns.editing_item, trait_params)
      end

    case result do
      {:ok, trait} ->
        {:noreply,
         socket
         |> put_flash(:info, "Parent trait saved successfully.")
         |> assign(
           :parent_traits,
           TraitManager.list_parent_traits(scope, socket.assigns.search_query)
         )
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, trait.id)
         )
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_parent_trait", _params, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    case TraitManager.delete_parent_trait(scope, parent_trait) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Parent trait and children deleted successfully.")
         |> assign(
           :parent_traits,
           TraitManager.list_parent_traits(scope, socket.assigns.search_query)
         )
         |> assign(:selected_parent_trait, nil)
         |> assign(:editor_mode, nil)}

      {:error, :has_associations} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete trait with active associations (tags or groups).")}
    end
  end

  def handle_event("new_child_traits", _params, socket) do
    {:noreply,
     socket
     |> assign(:editor_mode, :new_children)
     |> assign(:batch_traits_text, "")}
  end

  def handle_event("save_child_traits", %{"traits_text" => traits_text}, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    {:ok, %{created: created, failed: failed}} =
      TraitManager.batch_create_child_traits(scope, parent_trait, traits_text)

    message =
      if failed > 0 do
        "#{created} child traits created, #{failed} failed."
      else
        "#{created} child traits created successfully."
      end

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> assign(
       :selected_parent_trait,
       TraitManager.get_parent_trait_with_details(scope, parent_trait.id)
     )
     |> assign(:editor_mode, nil)
     |> assign(:batch_traits_text, "")}
  end

  def handle_event("edit_child_trait", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    child_trait = TraitManager.get_child_trait!(scope, id)
    changeset = Trait.changeset(child_trait, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_child)
     |> assign(:editing_item, child_trait)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save_child_trait", %{"trait" => trait_params}, socket) do
    scope = socket.assigns.current_scope
    child_trait = socket.assigns.editing_item
    parent_id = socket.assigns.selected_parent_trait.id

    case TraitManager.update_child_trait(scope, child_trait, trait_params) do
      {:ok, _trait} ->
        {:noreply,
         socket
         |> put_flash(:info, "Child trait updated successfully.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_id)
         )
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_child_trait", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    child_trait = TraitManager.get_child_trait!(scope, id)
    parent_id = socket.assigns.selected_parent_trait.id

    case TraitManager.delete_child_trait(scope, child_trait) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Child trait deleted successfully.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_id)
         )
         |> assign(:editor_mode, nil)}

      {:error, :has_associations} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete trait with active associations (tags or groups).")}
    end
  end

  def handle_event("new_survey_question", _params, socket) do
    changeset = SurveyQuestion.changeset(%SurveyQuestion{}, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :new_survey_question)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save_survey_question", %{"survey_question" => question_params}, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    case TraitManager.create_survey_question(scope, parent_trait, question_params) do
      {:ok, _question} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey question created with answers for all children.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_trait.id)
         )
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("edit_survey_question", _params, socket) do
    question = socket.assigns.selected_parent_trait.survey_question
    changeset = SurveyQuestion.changeset(question, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_survey_question)
     |> assign(:editing_item, question)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("update_survey_question", %{"survey_question" => question_params}, socket) do
    scope = socket.assigns.current_scope
    question = socket.assigns.editing_item
    parent_id = socket.assigns.selected_parent_trait.id

    case TraitManager.update_survey_question(scope, question, question_params) do
      {:ok, _question} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey question updated successfully.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_id)
         )
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("new_survey_answers", _params, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    case TraitManager.create_survey_answers_for_missing_children(scope, parent_trait) do
      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{count} survey answers created.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_trait.id)
         )}

      {:error, :no_survey_question} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please create a survey question first.")}
    end
  end

  def handle_event("edit_survey_answer", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    answer = TraitManager.get_survey_answer!(scope, id)
    changeset = SurveyAnswer.changeset(answer, %{})

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_survey_answer)
     |> assign(:editing_item, answer)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("update_survey_answer", %{"survey_answer" => answer_params}, socket) do
    scope = socket.assigns.current_scope
    answer = socket.assigns.editing_item
    parent_id = socket.assigns.selected_parent_trait.id

    case TraitManager.update_survey_answer(scope, answer, answer_params) do
      {:ok, _answer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Survey answer updated successfully.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_id)
         )
         |> assign(:editor_mode, nil)
         |> assign(:form, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("restripe_display_order", _params, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    case TraitManager.restripe_child_display_order(scope, parent_trait) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display order restriped successfully.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_trait.id)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to restripe display order.")}
    end
  end

  def handle_event("restripe_display_order_alphabetically", _params, socket) do
    scope = socket.assigns.current_scope
    parent_trait = socket.assigns.selected_parent_trait

    case TraitManager.restripe_child_display_order_alphabetically(scope, parent_trait) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display order restriped alphabetically.")
         |> assign(
           :selected_parent_trait,
           TraitManager.get_parent_trait_with_details(scope, parent_trait.id)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to restripe display order.")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editor_mode, nil)
     |> assign(:editing_item, nil)
     |> assign(:form, nil)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-[1600px]">
              <.page_header
                title="Trait manager"
                count={length(@parent_traits)}
                subtitle="Parent traits, their child traits, and the survey question and answers that tag them."
              >
                <:actions>
                  <button type="button" phx-click="new_parent_trait" class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="size-4" /> New parent trait
                  </button>
                </:actions>
              </.page_header>

              <div class="grid items-start gap-6 xl:grid-cols-[220px_minmax(0,1fr)_300px] 2xl:grid-cols-[260px_minmax(0,1fr)_360px]">
                <.parent_trait_list
                  parent_traits={@parent_traits}
                  search_query={@search_query}
                  selected_parent_trait={@selected_parent_trait}
                />

                <div class="min-w-0">
                  <%= if @selected_parent_trait do %>
                    <.parent_trait_details parent_trait={@selected_parent_trait} />
                  <% else %>
                    <.panel>
                      <.empty_state icon="hero-square-3-stack-3d" title="Select a parent trait">
                        Pick one from the list to see its child traits and survey.
                      </.empty_state>
                    </.panel>
                  <% end %>
                </div>

                <div class="xl:sticky xl:top-6">
                  <%= case @editor_mode do %>
                    <% :new_parent -> %>
                      <.parent_trait_form
                        form={@form}
                        trait_categories={@trait_categories}
                        mode="new"
                        on_save="save_parent_trait"
                        on_cancel="cancel_edit"
                      />
                    <% :edit_parent -> %>
                      <.parent_trait_form
                        form={@form}
                        trait_categories={@trait_categories}
                        parent_trait={@editing_item}
                        mode="edit"
                        can_delete={@can_delete_parent}
                        on_save="save_parent_trait"
                        on_cancel="cancel_edit"
                        on_delete="delete_parent_trait"
                      />
                    <% :new_children -> %>
                      <.batch_children_form
                        parent_trait={@selected_parent_trait}
                        batch_traits_text={@batch_traits_text}
                        on_save="save_child_traits"
                        on_cancel="cancel_edit"
                      />
                    <% :edit_child -> %>
                      <.child_trait_form
                        form={@form}
                        child_trait={@editing_item}
                        show_skip={@selected_parent_trait.input_type != "single_select_zip"}
                        on_save="save_child_trait"
                        on_cancel="cancel_edit"
                        on_delete={JS.push("delete_child_trait", value: %{id: @editing_item.id})}
                      />
                    <% :new_survey_question -> %>
                      <.survey_question_form
                        form={@form}
                        parent_trait={@selected_parent_trait}
                        mode="new"
                        on_save="save_survey_question"
                        on_cancel="cancel_edit"
                      />
                    <% :edit_survey_question -> %>
                      <.survey_question_form
                        form={@form}
                        parent_trait={@selected_parent_trait}
                        survey_question={@editing_item}
                        mode="edit"
                        on_save="update_survey_question"
                        on_cancel="cancel_edit"
                      />
                    <% :edit_survey_answer -> %>
                      <.survey_answer_form
                        form={@form}
                        survey_answer={@editing_item}
                        on_save="update_survey_answer"
                        on_cancel="cancel_edit"
                      />
                    <% nil -> %>
                      <.panel>
                        <.empty_state icon="hero-pencil-square" title="Select something to edit">
                          Use an edit or add button to open its form here.
                        </.empty_state>
                      </.panel>
                  <% end %>
                </div>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp parent_trait_list(assigns) do
    ~H"""
    <.panel flush title="Parent traits">
      <div class="border-b border-base-300 px-4 py-3">
        <form phx-change="search">
          <label class="input input-sm w-full">
            <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
            <input
              type="text"
              placeholder="Search"
              class="grow"
              value={@search_query}
              phx-debounce="300"
              name="search"
              autocomplete="off"
            />
            <button
              :if={@search_query != ""}
              type="button"
              phx-click="clear_search"
              class="btn btn-ghost btn-xs btn-circle"
              aria-label="Clear search"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </label>
        </form>
      </div>

      <p :if={@parent_traits == []} class="px-6 py-4 text-sm text-base-content/60">
        No parent traits found.
      </p>

      <ul :if={@parent_traits != []} class="max-h-[600px] space-y-0.5 overflow-y-auto p-2">
        <li :for={trait <- @parent_traits}>
          <button
            type="button"
            phx-click="select_parent"
            phx-value-id={trait.id}
            class={[
              "flex w-full items-center justify-between gap-2 rounded-lg px-3 py-2 text-left text-sm transition-colors",
              if(@selected_parent_trait && @selected_parent_trait.id == trait.id,
                do: "bg-primary/10 font-medium text-primary",
                else: "hover:bg-base-200/60"
              )
            ]}
          >
            <span class="min-w-0 flex-1 truncate">{trait.trait_name}</span>
            <.icon name="hero-chevron-right" class="size-4 shrink-0 text-base-content/40" />
          </button>
        </li>
      </ul>
    </.panel>
    """
  end

  defp parent_trait_details(assigns) do
    ~H"""
    <.panel flush title={@parent_trait.trait_name} description={parent_trait_summary(@parent_trait)}>
      <:actions>
        <.icon_button
          icon="hero-pencil-square"
          label="Edit parent trait"
          phx-click="edit_parent_trait"
        />
      </:actions>

      <div class="flex items-start justify-between gap-4 border-b border-base-300 px-6 py-4">
        <div class="min-w-0">
          <p class="text-xs text-base-content/50">Survey question</p>
          <div class="mt-0.5 break-words text-sm">
            <%= if @parent_trait.survey_question do %>
              {raw(@parent_trait.survey_question.text)}
            <% else %>
              <span class="text-base-content/40">No survey question yet.</span>
            <% end %>
          </div>
        </div>
        <%= if @parent_trait.survey_question do %>
          <.icon_button
            icon="hero-pencil-square"
            label="Edit survey question"
            phx-click="edit_survey_question"
          />
        <% else %>
          <button type="button" phx-click="new_survey_question" class="btn btn-sm btn-ghost">
            <.icon name="hero-plus" class="size-4" /> Add question
          </button>
        <% end %>
      </div>

      <%= if @parent_trait.input_type == "single_select_zip" do %>
        <.empty_state
          icon="hero-map-pin"
          title={"Zip code data: #{@parent_trait.child_traits_count} entries"}
        >
          Zip code data is managed automatically and cannot be edited individually.
        </.empty_state>
      <% else %>
        <div class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 px-6 py-3">
          <div class="flex items-center gap-2">
            <h3 class="text-sm font-semibold">Child traits</h3>
            <span class="rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/70">
              {length(@parent_trait.child_traits)}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-1">
            <button type="button" phx-click="new_child_traits" class="btn btn-sm btn-ghost">
              <.icon name="hero-plus" class="size-4" /> Add child traits
            </button>
            <button type="button" phx-click="new_survey_answers" class="btn btn-sm btn-ghost">
              <.icon name="hero-plus" class="size-4" /> Add survey answers
            </button>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm">
            <thead class="border-b border-base-300 bg-base-200/40 text-xs text-base-content/60">
              <tr>
                <th class="px-6 py-3 font-medium">Child trait</th>
                <th class="px-3 py-3 text-center font-medium">Order</th>
                <th class="px-3 py-3 text-center font-medium">Tags</th>
                <th class="px-3 py-3 text-center font-medium">Groups</th>
                <th class="w-0 px-3 py-3"><span class="sr-only">Edit child trait</span></th>
                <th class="border-l border-base-300 px-6 py-3 font-medium">Survey answer</th>
                <th class="w-0 px-3 py-3"><span class="sr-only">Edit survey answer</span></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-300">
              <tr :if={@parent_trait.child_traits == []}>
                <td colspan="7" class="px-6 py-4 text-sm text-base-content/60">
                  No child traits yet.
                </td>
              </tr>
              <tr
                :for={child <- @parent_trait.child_traits}
                class="transition-colors hover:bg-base-200/40"
              >
                <td class="px-6 py-2.5 align-middle">
                  <span class="inline-flex items-center gap-2">
                    {child.trait_name}
                    <.status_badge :if={child.is_skipped_tag}>Skip</.status_badge>
                  </span>
                  <span
                    :if={child.search_terms != []}
                    class="block text-xs text-base-content/50"
                  >
                    Also: {Enum.join(child.search_terms, ", ")}
                  </span>
                </td>
                <td class="px-3 py-2.5 text-center align-middle">{child.display_order}</td>
                <td class="px-3 py-2.5 text-center align-middle">{child.tags_count}</td>
                <td class="px-3 py-2.5 text-center align-middle">{child.grps_count}</td>
                <td class="px-3 py-2.5 align-middle">
                  <.icon_button
                    icon="hero-pencil-square"
                    label="Edit child trait"
                    phx-click="edit_child_trait"
                    phx-value-id={child.id}
                  />
                </td>
                <td class="border-l border-base-300 px-6 py-2.5 align-middle">
                  <%= if child.survey_answer do %>
                    {child.survey_answer.text}
                  <% else %>
                    <span class="text-base-content/40">-</span>
                  <% end %>
                </td>
                <td class="px-3 py-2.5 align-middle">
                  <.icon_button
                    :if={child.survey_answer}
                    icon="hero-pencil-square"
                    label="Edit survey answer"
                    phx-click="edit_survey_answer"
                    phx-value-id={child.survey_answer.id}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>

      <:footer :if={@parent_trait.input_type != "single_select_zip"}>
        <span class="mr-auto text-xs text-base-content/50">Display order</span>
        <button type="button" phx-click="restripe_display_order" class="btn btn-sm btn-ghost">
          <.icon name="hero-arrows-up-down" class="size-4" /> Restripe as current
        </button>
        <button
          type="button"
          phx-click="restripe_display_order_alphabetically"
          class="btn btn-sm btn-ghost"
        >
          <.icon name="hero-bars-arrow-down" class="size-4" /> Restripe alphabetically
        </button>
      </:footer>
    </.panel>
    """
  end

  defp parent_trait_summary(parent_trait) do
    category =
      if parent_trait.trait_category, do: parent_trait.trait_category.name, else: "None"

    [
      "Category: #{category}",
      parent_trait.has_search_filter && "Search filter on",
      parent_trait.search_terms != [] && "Also: #{Enum.join(parent_trait.search_terms, ", ")}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp parent_trait_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@on_save}>
      <.panel
        title={if @mode == "new", do: "New parent trait", else: "Edit parent trait"}
        description={if @mode == "edit", do: @parent_trait.trait_name}
      >
        <.input field={@form[:trait_name]} type="text" label="Trait name" required />

        <fieldset class="fieldset mb-2">
          <label>
            <span class="fieldset-label mb-1">Input type</span>
            <select name="trait[input_type]" class="select w-full" required>
              <option value="">Select input type...</option>
              <option
                value="single_select"
                selected={Phoenix.HTML.Form.input_value(@form, :input_type) == "single_select"}
              >
                Single Select
              </option>
              <option
                value="multi_select"
                selected={Phoenix.HTML.Form.input_value(@form, :input_type) == "multi_select"}
              >
                Multi Select
              </option>
              <option
                value="single_select_zip"
                selected={Phoenix.HTML.Form.input_value(@form, :input_type) == "single_select_zip"}
              >
                Zip Select
              </option>
            </select>
          </label>
        </fieldset>

        <fieldset class="fieldset mb-2">
          <label>
            <span class="fieldset-label mb-1">Trait category</span>
            <select name="trait[trait_category_id]" class="select w-full" required>
              <option value="">Select category...</option>
              <option
                :for={category <- @trait_categories}
                value={category.id}
                selected={Phoenix.HTML.Form.input_value(@form, :trait_category_id) == category.id}
              >
                {category.name}
              </option>
            </select>
          </label>
        </fieldset>

        <.input
          :if={@mode == "edit"}
          field={@form[:display_order]}
          type="number"
          label="Display order"
          required
        />

        <div>
          <.input
            field={@form[:has_search_filter]}
            type="checkbox"
            label="Show a search box when tagging"
          />
          <p class="text-xs text-base-content/60">
            Matches the title, answer text, and meta fields. Zip parents keep the zip picker.
          </p>
        </div>

        <.search_terms_input form={@form} />

        <p
          :if={@mode == "edit" && assigns[:on_delete] && assigns[:can_delete] == false}
          class="text-xs text-base-content/60"
        >
          Cannot delete: trait or children have active tags or groups
        </p>

        <:footer>
          <button
            :if={@mode == "edit" && assigns[:on_delete]}
            type="button"
            phx-click={assigns[:can_delete] != false && @on_delete}
            data-confirm={
              assigns[:can_delete] != false &&
                "Delete this parent trait and all children? This cannot be undone."
            }
            disabled={assigns[:can_delete] == false}
            class="btn btn-sm btn-ghost mr-auto text-error"
            title={
              assigns[:can_delete] == false &&
                "Cannot delete: trait or children have active tags or groups"
            }
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  defp batch_children_form(assigns) do
    ~H"""
    <.form for={%{}} phx-submit={@on_save}>
      <.panel title="Add child traits" description={"Parent trait: #{@parent_trait.trait_name}"}>
        <fieldset class="fieldset mb-2">
          <label>
            <span class="fieldset-label mb-1">New traits, one per line</span>
            <textarea
              name="traits_text"
              class="textarea h-64 w-full text-sm"
              placeholder="Enter trait names, one per line"
            >{@batch_traits_text}</textarea>
          </label>
        </fieldset>
        <:footer>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Adding...">Add trait(s)</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  attr :form, :any, required: true

  defp search_terms_input(assigns) do
    ~H"""
    <div>
      <.input
        field={@form[:search_terms]}
        type="text"
        label="Search terms"
        value={search_terms_value(@form)}
        placeholder="ceramics, clay, wheel throwing"
      />
      <p class="text-xs text-base-content/60">
        Comma-separated words people might use for this ({Trait.max_search_terms()} at most). Builder search and assistants' trait search match them.
      </p>
    </div>
    """
  end

  defp search_terms_value(form) do
    case Phoenix.HTML.Form.input_value(form, :search_terms) do
      terms when is_list(terms) -> Enum.join(terms, ", ")
      terms when is_binary(terms) -> terms
      _ -> ""
    end
  end

  defp child_trait_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@on_save}>
      <.panel title="Edit child trait" description={@child_trait.trait_name}>
        <p :if={@child_trait.is_skipped_tag} class="flex items-center gap-2 text-sm">
          <.status_badge>Skip</.status_badge>
          <span class="text-base-content/60">This child is the skip answer.</span>
        </p>

        <div class="grid gap-x-4 sm:grid-cols-2 xl:grid-cols-1">
          <.input field={@form[:trait_name]} type="text" label="Trait name" required />
          <.input field={@form[:display_order]} type="number" label="Display order" required />
        </div>

        <.search_terms_input form={@form} />

        <div :if={@show_skip}>
          <.input field={@form[:is_skipped_tag]} type="checkbox" label="Skip answer" />
          <p class="text-xs text-base-content/60">
            <%= if @child_trait.is_skipped_tag do %>
              This parent must keep one skip answer. Check this on another child to move it.
            <% else %>
              Checking this moves the skip answer onto this child.
            <% end %>
          </p>
        </div>

        <:footer>
          <button
            type="button"
            phx-click={@on_delete}
            data-confirm="Delete this child trait? This cannot be undone."
            class="btn btn-sm btn-ghost mr-auto text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  defp survey_question_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@on_save}>
      <.panel
        title={if @mode == "new", do: "New survey question", else: "Edit survey question"}
        description={"Parent trait: #{@parent_trait.trait_name}"}
      >
        <fieldset class="fieldset mb-2">
          <label>
            <span class="fieldset-label mb-1">Survey question</span>
            <textarea name="survey_question[text]" class="textarea h-32 w-full" required>{Phoenix.HTML.Form.input_value(@form, :text)}</textarea>
          </label>
        </fieldset>
        <:footer>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Saving...">
            {if @mode == "new", do: "Create survey question", else: "Update survey question"}
          </.button>
        </:footer>
      </.panel>
    </.form>
    """
  end

  defp survey_answer_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@on_save}>
      <.panel title="Edit survey answer">
        <dl class="grid gap-x-6 gap-y-4">
          <.detail_item
            label="Parent trait"
            value={
              if @survey_answer.survey_question,
                do: @survey_answer.survey_question.trait.trait_name,
                else: "N/A"
            }
          />
          <.detail_item
            label="Current survey question"
            value={
              if @survey_answer.survey_question,
                do: @survey_answer.survey_question.text,
                else: "N/A"
            }
          />
          <.detail_item
            label="Selected trait"
            value={
              Enum.find(
                @survey_answer.survey_question.trait.child_traits,
                &(&1.id == @survey_answer.trait_id)
              ).trait_name
            }
          />
          <.detail_item label="Current survey answer" value={@survey_answer.text} />
        </dl>

        <fieldset class="fieldset mb-2">
          <label>
            <span class="fieldset-label mb-1">Survey answer</span>
            <textarea name="survey_answer[text]" class="textarea h-32 w-full" required>{Phoenix.HTML.Form.input_value(@form, :text)}</textarea>
          </label>
        </fieldset>
        <:footer>
          <button type="button" phx-click={@on_cancel} class="btn btn-ghost">Cancel</button>
          <.button variant="primary" phx-disable-with="Saving...">Update survey answer</.button>
        </:footer>
      </.panel>
    </.form>
    """
  end
end
