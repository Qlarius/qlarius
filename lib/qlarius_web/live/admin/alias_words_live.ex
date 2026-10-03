defmodule QlariusWeb.Admin.AliasWordsLive do
  use QlariusWeb, :live_view

  import Ecto.Query
  import QlariusWeb.Components.MarketerUI

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
        <AdminSidebar.sidebar current_user={@current_scope.user} current_path={@current_path} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-5xl">
              <.page_header
                title="Alias Words Manager"
                subtitle="Manage adjectives and nouns for alias generation."
              >
                <:actions>
                  <button type="button" phx-click="new_word" class="btn btn-primary btn-sm">
                    <.icon name="hero-plus" class="size-4" /> Add word
                  </button>
                </:actions>
              </.page_header>

              <div class="mb-6 grid gap-3 sm:grid-cols-3">
                <.stat_tile label="Total words" icon="hero-language">{@total_count}</.stat_tile>
                <.stat_tile label="Active" icon="hero-check-circle" value_class="text-success">
                  {@active_count}
                </.stat_tile>
                <.stat_tile label="Inactive" icon="hero-pause-circle">
                  {@inactive_count}
                </.stat_tile>
              </div>

              <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <div class="inline-flex rounded-lg border border-base-300 bg-base-100 p-0.5">
                  <button
                    :for={{type, label} <- [{"adjective", "Adjectives"}, {"noun", "Nouns"}]}
                    type="button"
                    phx-click="select_type"
                    phx-value-type={type}
                    aria-pressed={to_string(@selected_type == type)}
                    class={segment_class(@selected_type == type)}
                  >
                    {label}
                  </button>
                </div>

                <.form for={%{}} phx-change="search" class="w-full sm:max-w-xs">
                  <label class="input w-full">
                    <.icon name="hero-magnifying-glass" class="size-4 text-base-content/50" />
                    <input
                      type="search"
                      name="search"
                      placeholder="Search words"
                      value={@search_query}
                      phx-debounce="300"
                      autocomplete="off"
                      class="grow"
                    />
                  </label>
                </.form>
              </div>

              <.panel flush>
                <.empty_state
                  :if={@words == []}
                  icon="hero-language"
                  title={
                    if @search_query == "",
                      do: "No #{@selected_type}s yet",
                      else: "No words match \"#{@search_query}\""
                  }
                >
                  Words added here feed the alias generator.
                </.empty_state>

                <.data_table :if={@words != []} id="alias-words-table" rows={@words}>
                  <:col :let={word} label="Word">
                    <span class="font-medium">{word.word}</span>
                  </:col>
                  <:col :let={word} label="Status">
                    <.status_badge tone={if word.active, do: "success", else: "neutral"}>
                      {if word.active, do: "Active", else: "Inactive"}
                    </.status_badge>
                  </:col>
                  <:col :let={word} label="Created" class="max-sm:hidden">
                    <span class="text-base-content/60">
                      {Calendar.strftime(word.inserted_at, "%Y-%m-%d")}
                    </span>
                  </:col>
                  <:action :let={word}>
                    <.icon_button
                      icon="hero-pencil-square"
                      label="Edit"
                      phx-click="edit_word"
                      phx-value-id={word.id}
                    />
                  </:action>
                  <:action :let={word}>
                    <.icon_button
                      icon={if word.active, do: "hero-eye-slash", else: "hero-eye"}
                      label={if word.active, do: "Deactivate", else: "Activate"}
                      phx-click="toggle_active"
                      phx-value-id={word.id}
                    />
                  </:action>
                  <:action :let={word}>
                    <.icon_button
                      icon="hero-trash"
                      label="Delete"
                      tone="error"
                      phx-click="delete_word"
                      phx-value-id={word.id}
                      data-confirm="Are you sure you want to delete this word?"
                    />
                  </:action>
                </.data_table>
              </.panel>
            </.page>

            <div :if={@show_form} class="modal modal-open">
              <div class="modal-box max-w-md p-0">
                <.form
                  for={%{}}
                  phx-submit="save_word"
                  autocomplete="off"
                  data-form-type="other"
                >
                  <div class="px-6 pt-6 pb-5">
                    <h3 class="text-base font-semibold">
                      {if @editing_word, do: "Edit word", else: "Add new word"}
                    </h3>
                    <p class="mt-0.5 text-sm text-base-content/60">
                      Lowercase letters only.
                    </p>
                  </div>

                  <div class="space-y-4 px-6 pb-6">
                    <label class="block">
                      <span class="mb-1 block text-sm font-medium">Word</span>
                      <input
                        type="text"
                        name="word"
                        value={@form_word}
                        class="input w-full"
                        required
                        pattern="[a-z]+"
                        title="Lowercase letters only"
                      />
                    </label>

                    <label class="block">
                      <span class="mb-1 block text-sm font-medium">Type</span>
                      <select name="type" class="select w-full">
                        <option value="adjective" selected={@form_type == "adjective"}>
                          Adjective
                        </option>
                        <option value="noun" selected={@form_type == "noun"}>Noun</option>
                      </select>
                    </label>

                    <label class="flex cursor-pointer items-center gap-3">
                      <input
                        type="checkbox"
                        name="active"
                        value="true"
                        checked={@form_active}
                        class="checkbox checkbox-sm"
                      />
                      <span class="text-sm">Active</span>
                    </label>
                  </div>

                  <div class="flex items-center justify-end gap-2 rounded-b-2xl border-t border-base-300 bg-base-200/40 px-6 py-4">
                    <button type="button" phx-click="cancel_form" class="btn btn-ghost">
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary">Save word</button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp segment_class(true),
    do: "btn btn-sm border-0 bg-primary/10 text-primary shadow-none hover:bg-primary/15"

  defp segment_class(false), do: "btn btn-sm btn-ghost border-0 text-base-content/70"
end
