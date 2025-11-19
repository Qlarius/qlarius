defmodule QlariusWeb.MeFileHTML do
  use QlariusWeb, :html

  embed_templates "me_file_html/*"

  def progress_bar_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500"
      percentage > 0 -> "bg-orange-500"
      true -> "bg-red-500"
    end
  end

  def badge_color(percentage) do
    cond do
      percentage == 100.0 -> "bg-green-500 text-white"
      percentage > 0 -> "bg-orange-500 text-white"
      true -> "bg-red-500 text-white"
    end
  end

  attr :tag_count, :integer, required: true
  attr :trait_count, :integer, required: true

  def tag_and_trait_count_badges(assigns) do
    ~H"""
    <div class="flex gap-4 mb-6">
      <div class="bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content px-4 py-2 font-medium rounded-lg text-sm border border-youdata-300 dark:border-youdata-500">
        {@tag_count} tags
      </div>
      <%!-- <div class="bg-base-100 text-base-content px-3 py-1 rounded-full text-sm border border-neutral-300 dark:border-neutral-500">
        {@tag_count} tags
      </div> --%>
    </div>
    """
  end

  attr :trait_in_edit, :any, default: nil
  attr :me_file_id, :integer, required: true
  attr :selected_ids, :list, default: []
  attr :show_modal, :boolean, default: false
  attr :tag_edit_mode, :string, default: "update"
  attr :zip_lookup_input, :string, default: ""
  attr :zip_lookup_trait, :any, default: nil
  attr :zip_lookup_valid, :boolean, default: false
  attr :zip_lookup_error, :string, default: nil

  def tag_edit_modal(assigns) do
    ~H"""
    <div class={[
      "modal modal-bottom sm:modal-middle",
      @show_modal && "modal-open bg-base-300/80 backdrop-blur-sm"
    ]}>
      <div class="flex flex-col modal-box border border-youdata-500 dark:border-youdata-700 bg-base-100 p-0 max-h-[90vh]">
        <%!-- Fixed header --%>
        <div class="p-4 flex flex-row justify-between items-baseline bg-youdata-300/80 dark:bg-youdata-800/80 text-base-content shrink-0">
          <h3 class="text-lg font-bold">
            {if @trait_in_edit, do: @trait_in_edit.trait_name, else: "Edit Trait"}
          </h3>
          <button type="button" phx-click="close_modal" class="btn btn-md btn-circle btn-ghost">
            ✕
          </button>
        </div>

        <%!-- Expandable content area --%>
        <%= cond do %>
          <% @tag_edit_mode == "update" -> %>
            <%!-- Fixed question section --%>
            <div class="p-4 bg-base-200 text-base-content/70 shrink-0 text-lg">
              <p :if={@trait_in_edit && @trait_in_edit.survey_question}>
                {Phoenix.HTML.raw(@trait_in_edit.survey_question.text)}
              </p>
            </div>
            <.form
              :if={@trait_in_edit}
              for={%{}}
              phx-submit="save_tags"
              class="flex flex-col flex-1 min-h-0"
            >
              <div class="flex-1 overflow-y-auto p-4">
                <input type="hidden" name="me_file_id" value={@me_file_id} />
                <input type="hidden" name="trait_id" value={@trait_in_edit.id} />
                <div
                  :if={@trait_in_edit.input_type == "single_select_zip"}
                  class="space-y-4"
                >
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text text-lg">Enter 5-digit zip code:</span>
                    </label>
                    <input
                      type="text"
                      name="zip_code_input"
                      value={@zip_lookup_input}
                      phx-change="lookup_zip_code"
                      maxlength="5"
                      pattern="\d{5}"
                      inputmode="numeric"
                      autocomplete="postal-code"
                      data-1p-ignore="true"
                      data-lpignore="true"
                      data-form-type="other"
                      class="input input-bordered input-lg w-full text-lg"
                    />
                  </div>

                  <div class="min-h-[4rem]">
                    <div :if={@zip_lookup_trait && @zip_lookup_valid} class="space-y-2">
                      <div class="badge badge-primary badge-lg p-4">
                        <.icon name="hero-map-pin" class="w-5 h-5" />
                        {@zip_lookup_trait.meta_1}
                      </div>
                      <input
                        type="hidden"
                        name="child_trait_ids[]"
                        value={@zip_lookup_trait.id}
                      />
                    </div>

                    <div :if={@zip_lookup_error} class="alert alert-error">
                      <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
                      <span>{@zip_lookup_error}</span>
                    </div>
                  </div>
                </div>
                <div
                  :if={
                    @trait_in_edit.child_traits && @trait_in_edit.input_type != "single_select_zip"
                  }
                  class="py-0"
                >
                  <label
                    :for={
                      child_trait <- Enum.sort_by(@trait_in_edit.child_traits, & &1.display_order)
                    }
                    class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 py-4 px-2 hover:bg-base-200 cursor-pointer"
                  >
                    <input
                      :if={@trait_in_edit.input_type == "single_select"}
                      type="radio"
                      name="child_trait_ids[]"
                      value={child_trait.id}
                      id={"trait-#{child_trait.id}"}
                      checked={child_trait.id in @selected_ids}
                      class="radio w-7 h-7"
                    />
                    <input
                      :if={@trait_in_edit.input_type == "multi_select"}
                      type="checkbox"
                      name="child_trait_ids[]"
                      value={child_trait.id}
                      id={"trait-#{child_trait.id}"}
                      checked={child_trait.id in @selected_ids}
                      class="checkbox w-7 h-7"
                    />
                    <div class="text-lg text-base-content">
                      {if child_trait.survey_answer &&
                            child_trait.survey_answer.text not in [nil, ""],
                          do: child_trait.survey_answer.text,
                          else: child_trait.trait_name}
                    </div>
                  </label>
                </div>
              </div>

              <%!-- Fixed footer --%>
              <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
                <button type="button" phx-click="close_modal" class="btn btn-lg btn-ghost">
                  Cancel
                </button>
                <button
                  type="submit"
                  class="btn btn-lg btn-primary"
                  disabled={@trait_in_edit.input_type == "single_select_zip" && !@zip_lookup_valid}
                >
                  Save/Update Tags
                </button>
              </div>
            </.form>
          <% @tag_edit_mode == "delete" -> %>
            <.form
              :if={@trait_in_edit}
              for={%{}}
              phx-submit="perform_delete_tags"
              class="flex flex-col flex-1 min-h-0"
            >
              <div class="flex-1 overflow-y-auto p-4">
                <input type="hidden" name="me_file_id" value={@me_file_id} />
                <input type="hidden" name="trait_id" value={@trait_in_edit.id} />
                <%= for child_trait_id <- @selected_ids do %>
                  <input type="hidden" name="child_trait_ids[]" value={child_trait_id} />
                <% end %>
                <div class="space-y-4">
                  <div :if={@trait_in_edit.child_traits} class="py-0">
                    <%= for child_trait <- Enum.sort_by(@trait_in_edit.child_traits, & &1.display_order) do %>
                      <%= if child_trait.id in @selected_ids do %>
                        <div class="flex items-center gap-3 [&:not(:last-child)]:border-b border-dashed border-base-content/10 py-3 px-2">
                          <div class="text-lg text-base-content">
                            {child_trait.trait_name}
                          </div>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                  <div :if={Enum.empty?(@selected_ids)} class="text-center py-8 text-base-content/50">
                    No tags selected for deletion
                  </div>
                </div>
              </div>

              <%!-- Fixed question section --%>
              <div class="p-4 bg-error shrink-0">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <.icon name="hero-exclamation-triangle" class="h-7 w-7 text-white" />
                  </div>
                  <div class="ml-3">
                    <p class="text-sm font-medium text-white">
                      {if @trait_in_edit && @trait_in_edit.survey_question do
                        "Confirm that you want to delete this tag?"
                      else
                        "Confirm deletion"
                      end}
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Fixed footer --%>
              <div class="p-4 flex flex-row align-end gap-2 justify-end bg-base-200 border-t border-base-300 shrink-0">
                <button type="button" phx-click="close_modal" class="btn btn-lg btn-ghost">
                  Cancel
                </button>
                <button
                  type="submit"
                  class="btn btn-lg btn-error"
                  disabled={Enum.empty?(@selected_ids)}
                >
                  Delete Tag
                </button>
              </div>
            </.form>
          <% true -> %>
            <div class="flex-1 flex items-center justify-center p-8">
              <div class="text-base-content/50">Invalid edit mode</div>
            </div>
        <% end %>
      </div>
      <%!-- <pre :if={@trait_in_edit} class="py-4 overflow-auto max-h-96 whitespace-pre-wrap bg-base-200 rounded-lg p-4">{inspect(@trait_in_edit, pretty: true, width: 60)}</pre> --%>
    </div>
    """
  end
end
