defmodule QlariusWeb.Admin.TraitManagerLive do
  use QlariusWeb, :live_view

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
     |> assign(:batch_traits_text, "")}
  end

  def handle_event("search", %{"search" => search_query}, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:search_query, search_query)
     |> assign(:parent_traits, TraitManager.list_parent_traits(scope, search_query))}
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

    {:noreply,
     socket
     |> assign(:editor_mode, :edit_parent)
     |> assign(:editing_item, parent_trait)
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

    case TraitManager.batch_create_child_traits(scope, parent_trait, traits_text) do
      {:ok, %{created: created, failed: failed}} ->
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

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create child traits.")}
    end
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
      <div class="max-w-[1600px] mx-auto p-6">
        <h1 class="text-3xl font-bold mb-6">Trait Manager</h1>

        <div class="grid grid-cols-12 gap-6">
          <%!-- Column 1: Selector --%>
          <div class="col-span-2">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body p-4">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="card-title text-lg">
                    Parent Trait
                  </h2>
                  <button
                    phx-click="new_parent_trait"
                    class="btn btn-circle btn-sm btn-primary"
                    title="New Parent Trait"
                  >
                    <.icon name="hero-plus" class="w-5 h-5" />
                  </button>
                </div>

                <div class="form-control mb-4">
                  <form phx-change="search">
                    <input
                      type="text"
                      placeholder="Search by name..."
                      class="input input-bordered input-sm w-full"
                      value={@search_query}
                      phx-debounce="300"
                      name="search"
                    />
                  </form>
                </div>

                <div class="overflow-y-auto max-h-[600px] space-y-1">
                  <%= for trait <- @parent_traits do %>
                    <div class={[
                      "flex items-center justify-between p-2 rounded hover:bg-base-200 cursor-pointer",
                      @selected_parent_trait && @selected_parent_trait.id == trait.id &&
                        "bg-primary/10"
                    ]}>
                      <span class="text-sm truncate flex-1">{trait.trait_name}</span>
                      <button
                        phx-click="select_parent"
                        phx-value-id={trait.id}
                        class="link link-primary text-xs"
                      >
                        Select
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Column 2: Details --%>
          <div class="col-span-7">
            <%= if @selected_parent_trait do %>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body p-4">
                  <%!-- Combined Table with Parent Trait, Survey Question, Child Traits, and Survey Answers --%>
                  <div class="overflow-x-auto mb-4">
                    <table class="table table-xs">
                      <thead>
                        <%!-- Top header row: Parent Trait and Survey Question --%>
                        <tr>
                          <th colspan="5" class="bg-primary/30 text-base font-bold">
                            <div class="flex items-center justify-between">
                              <span>Parent Trait</span>
                              <button
                                phx-click="edit_parent_trait"
                                class="btn btn-xs btn-ghost"
                                title="Edit Parent Trait"
                              >
                                <.icon name="hero-pencil-square" class="w-3 h-3" />
                              </button>
                            </div>
                          </th>
                          <th
                            colspan="2"
                            class="bg-secondary/30 text-base font-bold border-l-4 border-base-300"
                          >
                            <div class="flex items-center justify-between">
                              <span>Survey Question</span>
                              <%= if @selected_parent_trait.survey_question do %>
                                <button
                                  phx-click="edit_survey_question"
                                  class="btn btn-xs btn-ghost"
                                  title="Edit Survey Question"
                                >
                                  <.icon name="hero-pencil-square" class="w-3 h-3" />
                                </button>
                              <% else %>
                                <button
                                  phx-click="new_survey_question"
                                  class="btn btn-xs btn-circle btn-primary"
                                  title="Add Survey Question"
                                >
                                  <.icon name="hero-plus" class="w-3 h-3" />
                                </button>
                              <% end %>
                            </div>
                          </th>
                        </tr>
                        <%!-- Parent Trait and Survey Question content row --%>
                        <tr>
                          <td colspan="5" class="bg-primary/10 font-semibold">
                            <div>
                              <p class="text-base">{@selected_parent_trait.trait_name}</p>
                              <p class="text-xs text-base-content/70">
                                Category: {if @selected_parent_trait.trait_category,
                                  do: @selected_parent_trait.trait_category.name,
                                  else: "None"}
                              </p>
                            </div>
                          </td>
                          <td colspan="2" class="bg-secondary/10 border-l-4 border-base-300">
                            <p class="text-sm">
                              {if @selected_parent_trait.survey_question,
                                do: @selected_parent_trait.survey_question.text,
                                else: "--"}
                            </p>
                          </td>
                        </tr>
                        <%!-- Child Traits and Survey Answer headers --%>
                        <tr>
                          <th class="bg-primary/20">Child Traits</th>
                          <th class="bg-primary/20 text-center">Ordr</th>
                          <th class="bg-primary/20 text-center">Tags</th>
                          <th class="bg-primary/20 text-center">Grps</th>
                          <th class="bg-primary/20 text-center">
                            <button
                              phx-click="new_child_traits"
                              class="btn btn-xs btn-circle btn-primary"
                              title="Add Child Traits"
                            >
                              <.icon name="hero-plus" class="w-3 h-3" />
                            </button>
                          </th>
                          <th class="bg-secondary/20 border-l-4 border-base-300">Survey Answer</th>
                          <th class="bg-secondary/20 text-center">
                            <button
                              phx-click="new_survey_answers"
                              class="btn btn-xs btn-circle btn-primary"
                              title="Add Survey Answers"
                            >
                              <.icon name="hero-plus" class="w-3 h-3" />
                            </button>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for child <- @selected_parent_trait.child_traits do %>
                          <tr class="hover">
                            <td>{child.trait_name}</td>
                            <td class="text-center">{child.display_order}</td>
                            <td class="text-center">{child.tags_count}</td>
                            <td class="text-center">{child.grps_count}</td>
                            <td class="text-center">
                              <button
                                phx-click="edit_child_trait"
                                phx-value-id={child.id}
                                class="btn btn-xs btn-ghost"
                              >
                                <.icon name="hero-pencil-square" class="w-3 h-3" />
                              </button>
                            </td>
                            <td class="border-l-4 border-base-300">
                              {if child.survey_answer, do: child.survey_answer.text, else: "--"}
                            </td>
                            <td class="text-center">
                              <%= if child.survey_answer do %>
                                <button
                                  phx-click="edit_survey_answer"
                                  phx-value-id={child.survey_answer.id}
                                  class="btn btn-xs btn-ghost"
                                >
                                  <.icon name="hero-pencil-square" class="w-3 h-3" />
                                </button>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>

                  <div class="mt-2">
                    <button phx-click="restripe_display_order" class="btn btn-sm btn-warning">
                      Restripe Display Order as Current
                    </button>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <p class="text-center text-base-content/50">Select something to edit</p>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Column 3: Editor --%>
          <div class="col-span-3">
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
                <div class="card bg-base-100 shadow-xl">
                  <div class="card-body">
                    <p class="text-center text-base-content/50">Select something to edit</p>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp parent_trait_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl mb-4">
          <.icon
            name={if @mode == "new", do: "hero-plus-circle", else: "hero-pencil-square"}
            class="w-6 h-6"
          />
          {if @mode == "new", do: "New Parent Trait", else: "Edit Parent Trait"}
        </h2>

        <%= if @mode == "edit" do %>
          <p class="text-base-content/70 mb-4">{@parent_trait.trait_name}</p>
        <% end %>

        <.form for={@form} phx-submit={@on_save}>
          <div class="space-y-4">
            <.input
              field={@form[:trait_name]}
              type="text"
              label="Trait name"
              class="input input-bordered w-full"
              required
            />

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Input type</span>
              </label>
              <select
                name="trait[input_type]"
                class="select select-bordered w-full"
                required
              >
                <option value="">Select input type...</option>
                <option
                  value="SingleSelect"
                  selected={Phoenix.HTML.Form.input_value(@form, :input_type) == "SingleSelect"}
                >
                  Single Select
                </option>
                <option
                  value="MultiSelect"
                  selected={Phoenix.HTML.Form.input_value(@form, :input_type) == "MultiSelect"}
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
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Trait category</span>
              </label>
              <select
                name="trait[trait_category_id]"
                class="select select-bordered w-full"
                required
              >
                <option value="">Select category...</option>
                <%= for category <- @trait_categories do %>
                  <option
                    value={category.id}
                    selected={Phoenix.HTML.Form.input_value(@form, :trait_category_id) == category.id}
                  >
                    {category.name}
                  </option>
                <% end %>
              </select>
            </div>

            <%= if @mode == "edit" do %>
              <.input
                field={@form[:display_order]}
                type="number"
                label="Display order"
                class="input input-bordered w-full"
                required
              />
            <% end %>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary flex-1">
                Save/update trait
              </button>
              <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
                Cancel
              </button>
            </div>

            <%= if @mode == "edit" && assigns[:on_delete] do %>
              <button
                type="button"
                phx-click={@on_delete}
                data-confirm="Delete this parent trait and all children? This cannot be undone."
                class="btn btn-error w-full"
              >
                Delete Parent Trait (and Children)
              </button>
            <% end %>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp batch_children_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl mb-2">
          <.icon name="hero-plus-circle" class="w-6 h-6" /> Add New Traits
        </h2>
        <p class="text-base-content/70 mb-4">
          Parent Trait: <span class="font-semibold">{@parent_trait.trait_name}</span>
        </p>

        <.form for={%{}} phx-submit={@on_save}>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text font-semibold">New traits (one per line)</span>
            </label>
            <textarea
              name="traits_text"
              class="textarea textarea-bordered textarea-lg h-64 font-mono text-sm"
              placeholder="Enter trait names, one per line..."
            >{@batch_traits_text}</textarea>
          </div>

          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary flex-1">
              Add trait(s)
            </button>
            <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
              Cancel
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp child_trait_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl mb-2">
          <.icon name="hero-pencil-square" class="w-6 h-6" /> Edit Child Trait
        </h2>
        <p class="text-base-content/70 mb-4">{@child_trait.trait_name}</p>

        <.form for={@form} phx-submit={@on_save}>
          <div class="space-y-4">
            <.input
              field={@form[:trait_name]}
              type="text"
              label="Trait name"
              class="input input-bordered w-full"
              required
            />

            <.input
              field={@form[:display_order]}
              type="number"
              label="Display order"
              class="input input-bordered w-full"
              required
            />

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary flex-1">
                Save/update trait
              </button>
              <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
                Cancel
              </button>
            </div>

            <button
              type="button"
              phx-click={@on_delete}
              data-confirm="Delete this child trait? This cannot be undone."
              class="btn btn-error w-full"
            >
              Delete Trait
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp survey_question_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl mb-2">
          <.icon
            name={if @mode == "new", do: "hero-plus-circle", else: "hero-pencil-square"}
            class="w-6 h-6"
          />
          {if @mode == "new", do: "New Survey Question", else: "Edit Survey Question"}
        </h2>
        <p class="text-base-content/70 mb-4">
          Parent Trait: <span class="font-semibold">{@parent_trait.trait_name}</span>
        </p>

        <.form for={@form} phx-submit={@on_save}>
          <div class="space-y-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Survey question</span>
              </label>
              <textarea
                name="survey_question[text]"
                class="textarea textarea-bordered h-32"
                required
              >{Phoenix.HTML.Form.input_value(@form, :text)}</textarea>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary flex-1">
                {if @mode == "new", do: "Create survey question", else: "Update survey question"}
              </button>
              <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
                Cancel
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp survey_answer_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl mb-2">
          <.icon name="hero-pencil-square" class="w-6 h-6" /> Edit Survey Answer
        </h2>

        <div class="mb-4 space-y-2">
          <p class="text-sm">
            <span class="font-semibold">Parent Trait:</span>
            {if @survey_answer.survey_question,
              do: @survey_answer.survey_question.trait.trait_name,
              else: "N/A"}
          </p>
          <p class="text-sm">
            <span class="font-semibold">Current Survey Question:</span>
            {if @survey_answer.survey_question, do: @survey_answer.survey_question.text, else: "N/A"}
          </p>
          <p class="text-sm">
            <span class="font-semibold">Selected Trait:</span>
            {Enum.find(
              @survey_answer.survey_question.trait.child_traits,
              &(&1.id == @survey_answer.trait_id)
            ).trait_name}
          </p>
          <p class="text-sm">
            <span class="font-semibold">Current Survey Answer:</span>
            {@survey_answer.text}
          </p>
        </div>

        <.form for={@form} phx-submit={@on_save}>
          <div class="space-y-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Survey question</span>
              </label>
              <textarea
                name="survey_answer[text]"
                class="textarea textarea-bordered h-32"
                required
              >{Phoenix.HTML.Form.input_value(@form, :text)}</textarea>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary flex-1">
                Update survey answer
              </button>
              <button type="button" phx-click={@on_cancel} class="btn btn-ghost">
                Cancel
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
