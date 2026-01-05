defmodule QlariusWeb.Admin.AliasWordsLive do
  use QlariusWeb, :live_view

  import Ecto.Query
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Repo
  alias Qlarius.Accounts.{AliasWord, AliasGenerator}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Alias Words Manager")
     |> assign(:selected_type, "adjective")
     |> assign(:search_query, "")
     |> assign(:show_form, false)
     |> assign(:editing_word, nil)
     |> assign(:form_word, "")
     |> assign(:form_type, "adjective")
     |> assign(:form_active, true)
     |> load_words()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    type = Map.get(params, "type", "adjective")
    search = Map.get(params, "search", "")

    {:noreply,
     socket
     |> assign(:selected_type, type)
     |> assign(:search_query, search)
     |> load_words()}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/alias_words?type=#{type}")}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_words()}
  end

  @impl true
  def handle_event("new_word", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_word, nil)
     |> assign(:form_word, "")
     |> assign(:form_type, socket.assigns.selected_type)
     |> assign(:form_active, true)}
  end

  @impl true
  def handle_event("edit_word", %{"id" => id}, socket) do
    word = Repo.get!(AliasWord, id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_word, word)
     |> assign(:form_word, word.word)
     |> assign(:form_type, word.type)
     |> assign(:form_active, word.active)}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  @impl true
  def handle_event("save_word", params, socket) do
    word_text = String.trim(params["word"])
    word_type = params["type"]
    active = params["active"] == "true"

    changeset_params = %{word: word_text, type: word_type, active: active}

    result =
      if socket.assigns.editing_word do
        socket.assigns.editing_word
        |> AliasWord.changeset(changeset_params)
        |> Repo.update()
      else
        %AliasWord{}
        |> AliasWord.changeset(changeset_params)
        |> Repo.insert()
      end

    case result do
      {:ok, _word} ->
        AliasGenerator.refresh_cache()

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> put_flash(:info, "Word saved successfully")
         |> load_words()}

      {:error, changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Error: #{errors}")}
    end
  end

  @impl true
  def handle_event("delete_word", %{"id" => id}, socket) do
    word = Repo.get!(AliasWord, id)
    Repo.delete!(word)
    AliasGenerator.refresh_cache()

    {:noreply,
     socket
     |> put_flash(:info, "Word deleted successfully")
     |> load_words()}
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    word = Repo.get!(AliasWord, id)

    word
    |> AliasWord.changeset(%{active: !word.active})
    |> Repo.update!()

    AliasGenerator.refresh_cache()

    {:noreply,
     socket
     |> put_flash(:info, "Word status updated")
     |> load_words()}
  end

  defp load_words(socket) do
    type = socket.assigns.selected_type
    search = socket.assigns.search_query

    query =
      from w in AliasWord,
        where: w.type == ^type

    query =
      if search != "" do
        search_pattern = "%#{search}%"
        from w in query, where: ilike(w.word, ^search_pattern)
      else
        query
      end

    words = Repo.all(from w in query, order_by: [asc: w.word])

    active_count = Enum.count(words, & &1.active)
    inactive_count = Enum.count(words, &(!&1.active))

    assign(socket,
      words: words,
      total_count: length(words),
      active_count: active_count,
      inactive_count: inactive_count
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <div class="p-6">
              <div class="flex justify-between items-center mb-6">
                <div>
                  <h1 class="text-3xl font-bold">Alias Words Manager</h1>
                  <p class="text-base-content/60 mt-1">
                    Manage adjectives and nouns for alias generation
                  </p>
                </div>
                <button phx-click="new_word" class="btn btn-primary gap-2">
                  <.icon name="hero-plus" class="w-5 h-5" /> Add Word
                </button>
              </div>

              <%!-- Type Tabs --%>
              <div class="tabs tabs-boxed mb-6">
                <button
                  phx-click="select_type"
                  phx-value-type="adjective"
                  class={["tab", if(@selected_type == "adjective", do: "tab-active")]}
                >
                  Adjectives
                </button>
                <button
                  phx-click="select_type"
                  phx-value-type="noun"
                  class={["tab", if(@selected_type == "noun", do: "tab-active")]}
                >
                  Nouns
                </button>
              </div>

              <%!-- Stats --%>
              <div class="stats shadow mb-6">
                <div class="stat">
                  <div class="stat-title">Total Words</div>
                  <div class="stat-value">{@total_count}</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Active</div>
                  <div class="stat-value text-success">{@active_count}</div>
                </div>
                <div class="stat">
                  <div class="stat-title">Inactive</div>
                  <div class="stat-value text-error">{@inactive_count}</div>
                </div>
              </div>

              <%!-- Search --%>
              <div class="form-control mb-6">
                <.form for={%{}} phx-change="search" phx-debounce="300">
                  <input
                    type="text"
                    name="search"
                    placeholder="Search words..."
                    class="input input-bordered w-full max-w-xs"
                    value={@search_query}
                  />
                </.form>
              </div>

              <%!-- Word Form Modal --%>
              <%= if @show_form do %>
                <div class="modal modal-open">
                  <div class="modal-box">
                    <h3 class="font-bold text-lg mb-4">
                      {if @editing_word, do: "Edit Word", else: "Add New Word"}
                    </h3>

                    <.form
                      for={%{}}
                      phx-submit="save_word"
                      class="space-y-4"
                      autocomplete="off"
                      data-form-type="other"
                    >
                      <div class="form-control">
                        <label class="label">
                          <span class="label-text">Word</span>
                        </label>
                        <input
                          type="text"
                          name="word"
                          value={@form_word}
                          class="input input-bordered"
                          required
                          pattern="[a-z]+"
                          title="Lowercase letters only"
                        />
                      </div>

                      <div class="form-control">
                        <label class="label">
                          <span class="label-text">Type</span>
                        </label>
                        <select name="type" class="select select-bordered" value={@form_type}>
                          <option value="adjective">Adjective</option>
                          <option value="noun">Noun</option>
                        </select>
                      </div>

                      <div class="form-control">
                        <label class="label cursor-pointer">
                          <span class="label-text">Active</span>
                          <input
                            type="checkbox"
                            name="active"
                            value="true"
                            checked={@form_active}
                            class="checkbox"
                          />
                        </label>
                      </div>

                      <div class="modal-action">
                        <button type="button" phx-click="cancel_form" class="btn">
                          Cancel
                        </button>
                        <button type="submit" class="btn btn-primary">
                          Save
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              <% end %>

              <%!-- Words Table --%>
              <div class="overflow-x-auto">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th>Word</th>
                      <th>Status</th>
                      <th>Created</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for word <- @words do %>
                      <tr>
                        <td class="font-mono font-medium">{word.word}</td>
                        <td>
                          <div class={[
                            "badge",
                            if(word.active, do: "badge-success", else: "badge-error")
                          ]}>
                            {if word.active, do: "Active", else: "Inactive"}
                          </div>
                        </td>
                        <td class="text-sm text-base-content/60">
                          {Calendar.strftime(word.inserted_at, "%Y-%m-%d")}
                        </td>
                        <td>
                          <div class="flex gap-2">
                            <button
                              phx-click="edit_word"
                              phx-value-id={word.id}
                              class="btn btn-sm btn-ghost"
                              title="Edit"
                            >
                              <.icon name="hero-pencil" class="w-4 h-4" />
                            </button>
                            <button
                              phx-click="toggle_active"
                              phx-value-id={word.id}
                              class="btn btn-sm btn-ghost"
                              title={if word.active, do: "Deactivate", else: "Activate"}
                            >
                              <.icon
                                name={if word.active, do: "hero-eye-slash", else: "hero-eye"}
                                class="w-4 h-4"
                              />
                            </button>
                            <button
                              phx-click="delete_word"
                              phx-value-id={word.id}
                              data-confirm="Are you sure you want to delete this word?"
                              class="btn btn-sm btn-ghost text-error"
                              title="Delete"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
