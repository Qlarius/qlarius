defmodule QlariusWeb.Creators.AudiencesLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Marketers
  alias Qlarius.Creators
  alias Qlarius.Sponster.Campaigns.Targets
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}
  alias Qlarius.Tiqit.ContentAudiences
  alias Qlarius.Repo
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @impl true
  def mount(%{"creator_id" => creator_id}, _session, socket) do
    creator = Creators.accessible_creator!(socket.assigns.current_scope, creator_id)

    {:ok,
     socket
     |> assign(:creator, creator)
     |> assign(:page_title, "Audiences")
     |> assign(:selected, nil)
     |> assign(:questions, [])
     |> assign(:answers, [])
     |> assign(:parent_trait_id, nil)
     |> assign(:marketers, Marketers.list_user_marketers(socket.assigns.current_scope.user.id))
     |> reload_audiences()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:attach, attach_from_params(params))
      |> maybe_select(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:ok, target} =
      ContentAudiences.create_audience(socket.assigns.current_scope, socket.assigns.creator.id, %{
        title: "New audience"
      })

    {:noreply,
     socket
     |> reload_audiences()
     |> push_patch(to: edit_path(socket.assigns.creator, target, socket.assigns.attach))}
  end

  def handle_event("select", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket, to: edit_path(socket.assigns.creator, %{id: id}, socket.assigns.attach))}
  end

  def handle_event("save_title", %{"title" => title}, socket) do
    {:ok, _} = Targets.update_target(socket.assigns.selected, %{title: title})

    {:noreply,
     socket
     |> reload_audiences()
     |> assign(
       :selected,
       ContentAudiences.get_audience!(socket.assigns.creator.id, socket.assigns.selected.id)
     )
     |> put_flash(:info, "Audience renamed")}
  end

  def handle_event("pick_question", %{"parent_trait_id" => id}, socket) do
    parent_id = String.to_integer(id)

    {:noreply,
     socket
     |> assign(:parent_trait_id, parent_id)
     |> assign(:answers, ContentAudiences.list_answers(parent_id))}
  end

  def handle_event("search_questions", %{"q" => q}, socket) do
    {:noreply, assign(socket, :questions, ContentAudiences.list_questions(q))}
  end

  def handle_event("set_answers", %{"trait_ids" => ids}, socket) do
    ids = List.wrap(ids) |> Enum.map(&String.to_integer/1)

    {:ok, _} =
      ContentAudiences.set_question_answers(
        socket.assigns.current_scope,
        socket.assigns.selected,
        socket.assigns.parent_trait_id,
        ids
      )

    selected =
      ContentAudiences.get_audience!(socket.assigns.creator.id, socket.assigns.selected.id)

    {:noreply,
     socket
     |> reload_audiences()
     |> assign(:selected, selected)
     |> put_flash(:info, "Question updated")}
  end

  def handle_event("populate", _params, socket) do
    :ok = ContentAudiences.trigger_population(socket.assigns.selected)
    {:noreply, put_flash(socket, :info, "Population started")}
  end

  def handle_event("attach", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    content = load_attach_content!(socket.assigns.attach)

    case ContentAudiences.set_attachment(
           socket.assigns.current_scope,
           socket.assigns.selected,
           content,
           mode
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Audience attached as #{mode}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not attach: #{inspect(reason)}")}
    end
  end

  def handle_event("refine", _params, socket) do
    {:ok, copy} =
      ContentAudiences.copy_within_org(socket.assigns.current_scope, socket.assigns.selected)

    {:noreply,
     socket
     |> reload_audiences()
     |> push_patch(to: edit_path(socket.assigns.creator, copy, socket.assigns.attach))}
  end

  def handle_event("promote", %{"marketer_id" => marketer_id}, socket) do
    marketer_id = String.to_integer(marketer_id)

    case Targets.clone_across_orgs(
           socket.assigns.current_scope,
           socket.assigns.selected,
           {:marketer, marketer_id},
           populate: true
         ) do
      {:ok, clone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cloned into marketer org as “#{clone.title}”")
         |> push_navigate(to: ~p"/marketer/targets/#{clone.id}/edit")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not promote: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />
        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />
          <div class="overflow-auto p-6 space-y-6">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-bold">Audiences</h1>
                <p class="text-base-content/60">{@creator.name}</p>
              </div>
              <div class="flex gap-2">
                <.link navigate={~p"/creators/#{@creator.id}/insights"} class="btn btn-ghost">
                  Insights
                </.link>
                <button type="button" class="btn btn-primary" phx-click="new">New audience</button>
              </div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div class="card bg-base-100 shadow">
                <div class="card-body p-0">
                  <ul class="menu w-full">
                    <li :for={aud <- @audiences}>
                      <button
                        type="button"
                        phx-click="select"
                        phx-value-id={aud.id}
                        class={@selected && @selected.id == aud.id && "active"}
                      >
                        <span class="flex flex-col items-start">
                          <span>{aud.title}</span>
                          <span class="text-xs opacity-60">
                            {ContentAudiences.reach(aud)} people · {length(aud.used_on)} uses
                          </span>
                        </span>
                      </button>
                    </li>
                  </ul>
                  <p :if={@audiences == []} class="p-4 text-sm text-base-content/60">
                    No audiences yet. Create one to boost or restrict who sees this creator’s content.
                  </p>
                </div>
              </div>

              <div :if={@selected} class="lg:col-span-2 space-y-4">
                <div class="card bg-base-100 shadow">
                  <div class="card-body space-y-4">
                    <form phx-submit="save_title" class="flex gap-2">
                      <input
                        type="text"
                        name="title"
                        value={@selected.title}
                        class="input input-bordered grow"
                      />
                      <button class="btn">Rename</button>
                    </form>

                    <p class="text-sm text-warning">
                      Editing this audience changes every place it is attached.
                    </p>

                    <div class="flex flex-wrap gap-2">
                      <button type="button" class="btn btn-sm" phx-click="populate">
                        Refresh reach
                      </button>
                      <button type="button" class="btn btn-sm" phx-click="refine">
                        Copy to refine
                      </button>
                    </div>

                    <div :if={@attach} class="flex gap-2">
                      <button
                        type="button"
                        class="btn btn-sm btn-primary"
                        phx-click="attach"
                        phx-value-mode="boost"
                      >
                        Attach as relevance
                      </button>
                      <button
                        type="button"
                        class="btn btn-sm btn-outline"
                        phx-click="attach"
                        phx-value-mode="gate"
                      >
                        Attach as restriction
                      </button>
                    </div>

                    <form :if={@marketers != []} phx-submit="promote" class="flex gap-2 items-end">
                      <label class="form-control grow">
                        <span class="label-text">Promote with an ad</span>
                        <select name="marketer_id" class="select select-bordered">
                          <option :for={m <- @marketers} value={m.id}>{m.business_name}</option>
                        </select>
                      </label>
                      <button class="btn btn-secondary">Clone to marketer</button>
                    </form>
                  </div>
                </div>

                <div class="card bg-base-100 shadow">
                  <div class="card-body space-y-3">
                    <h3 class="font-semibold">Questions</h3>
                    <form phx-change="search_questions">
                      <input
                        type="search"
                        name="q"
                        placeholder="Search questions"
                        class="input input-bordered w-full"
                        phx-debounce="300"
                      />
                    </form>
                    <div class="flex flex-wrap gap-2">
                      <button
                        :for={q <- @questions}
                        type="button"
                        class="btn btn-xs"
                        phx-click="pick_question"
                        phx-value-parent_trait_id={q.id}
                      >
                        {q.trait_name}
                      </button>
                    </div>

                    <form :if={@answers != []} phx-submit="set_answers" class="space-y-2">
                      <p class="text-sm">Select the answers this audience requires.</p>
                      <label :for={a <- @answers} class="flex items-center gap-2">
                        <input type="checkbox" name="trait_ids[]" value={a.id} class="checkbox" />
                        <span>{a.trait_name}</span>
                      </label>
                      <button class="btn btn-primary btn-sm">Save answers</button>
                    </form>

                    <ul class="text-sm">
                      <li :for={band <- @selected.target_bands}>
                        {if band.is_bullseye == "1", do: "Bullseye", else: "Ring"}: {Enum.map(
                          band.trait_groups,
                          & &1.title
                        )
                        |> Enum.join(", ")}
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp reload_audiences(socket) do
    assign(socket, :audiences, ContentAudiences.list_audiences(socket.assigns.creator.id))
  end

  defp maybe_select(socket, %{"id" => id}) do
    selected = ContentAudiences.get_audience!(socket.assigns.creator.id, id)

    socket
    |> assign(:selected, selected)
    |> assign(:questions, socket.assigns[:questions] || [])
  end

  defp maybe_select(socket, _), do: assign(socket, :selected, socket.assigns[:selected])

  defp attach_from_params(%{"attach" => level, "attach_id" => id}) do
    %{level: String.to_existing_atom(level), id: String.to_integer(id)}
  end

  defp attach_from_params(_), do: nil

  defp edit_path(creator, target, nil),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}"

  defp edit_path(creator, target, %{level: level, id: id}),
    do: ~p"/creators/#{creator.id}/audiences/#{target.id}?attach=#{level}&attach_id=#{id}"

  defp load_attach_content!(%{level: :creator, id: id}), do: Creators.get_creator!(id)
  defp load_attach_content!(%{level: :catalog, id: id}), do: Repo.get!(Catalog, id)
  defp load_attach_content!(%{level: :group, id: id}), do: Repo.get!(ContentGroup, id)
  defp load_attach_content!(%{level: :piece, id: id}), do: Repo.get!(ContentPiece, id)
end
