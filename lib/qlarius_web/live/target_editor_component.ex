defmodule QlariusWeb.Live.TargetEditorComponent do
  @moduledoc """
  The band editor for a target, owned once for campaign targets and creator
  audiences. Both are a `Target` with the same bands; only the wording differs,
  and that comes from `copy`.

  The component loads bands and available groups itself and reloads after each
  change. A parent asks for a reload with
  `send_update(__MODULE__, id: id, reload: true)`.

  Messages sent to the parent LiveView:

    * `{__MODULE__, {:flash, kind, message}}` — the parent owns the flash
    * `{__MODULE__, :changed}` — band structure changed
    * `{__MODULE__, :populating}` — population was triggered
    * `{__MODULE__, :done}` — the person finished editing

  ## Assigns

    * `:id` — DOM id
    * `:target` — the `%Target{}`
    * `:owner` — `{:marketer, id}` or `{:creator, id}`
    * `:copy` — `Targeting.copy(:target)` or `Targeting.copy(:audience)`
    * `:show_me_file_counts?` — per-group MeFile counts beside each chip
  """

  use QlariusWeb, :live_component

  alias Qlarius.Sponster.Campaigns.{AntiGroupSuggestions, Targets}
  alias Qlarius.YouData.Traits
  alias QlariusWeb.Components.Targeting

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       bands: nil,
       loaded_target_id: nil,
       expanding_target: false,
       show_me_file_counts?: false,
       review_open?: false,
       review: nil,
       review_error: nil
     )}
  end

  @impl true
  def update(%{reload: true} = assigns, socket) do
    {:ok, socket |> assign(Map.delete(assigns, :reload)) |> load()}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.loaded_target_id == socket.assigns.target.id do
      {:ok, socket}
    else
      {:ok, load(socket)}
    end
  end

  defp load(socket) do
    target_id = socket.assigns.target.id
    bands = Targets.get_bands_for_target(target_id)
    available = Targets.get_available_trait_groups_for_target(target_id, socket.assigns.owner)
    suggestions = AntiGroupSuggestions.for_target(target_id)

    socket
    |> assign(:bands, bands)
    |> assign(:outermost_band, Targets.outermost_band(bands))
    |> assign(:available_trait_groups, available)
    |> assign(
      :me_file_counts,
      me_file_counts(socket.assigns.show_me_file_counts?, bands, available)
    )
    |> assign(:suggestions, suggestions)
    |> assign(:suggestion_count, AntiGroupSuggestions.count(suggestions))
    |> assign(:expanding_target, false)
    |> assign(:loaded_target_id, target_id)
    |> refresh_review()
  end

  # Keeps the open review in step with fresh suggestions: answers that are no
  # longer suggested drop out of the selection, new ones start selected.
  defp refresh_review(%{assigns: %{review_open?: true, review: review}} = socket)
       when not is_nil(review) do
    assign(socket, :review, rebase_review(review, socket.assigns))
  end

  defp refresh_review(socket), do: socket

  defp new_review(assigns) do
    %{
      selected: MapSet.new(suggested_ids(assigns.suggestions)),
      titles: %{},
      shape: "combined",
      combined_title: nil,
      band_ids: Enum.map(assigns.bands, & &1.id)
    }
  end

  defp rebase_review(review, assigns) do
    suggested = MapSet.new(suggested_ids(assigns.suggestions))
    band_ids = Enum.map(assigns.bands, & &1.id)

    %{
      review
      | selected: MapSet.intersection(review.selected, suggested),
        band_ids: Enum.filter(review.band_ids, &(&1 in band_ids))
    }
  end

  defp suggested_ids(%{topics: topics}) do
    for topic <- topics, %{trait: trait} <- topic.traits, do: trait.id
  end

  defp me_file_counts(false, _bands, _available), do: nil

  defp me_file_counts(true, bands, available) do
    bands
    |> Enum.flat_map(& &1.trait_groups)
    |> Enum.concat(available)
    |> Enum.map(& &1.id)
    |> Enum.uniq()
    |> Traits.me_file_counts_for_trait_groups()
  end

  @impl true
  def handle_event("add_trait_group", %{"trait_group_id" => trait_group_id}, socket) do
    target_id = socket.assigns.target.id

    with {:ok, bullseye} <- bullseye_or_create(target_id),
         {:ok, _} <-
           Targets.add_trait_group_to_band(bullseye.id, String.to_integer(trait_group_id)) do
      {:noreply, changed(socket, "Trait group added to bullseye")}
    else
      {:error, :trait_group_already_in_target} ->
        {:noreply,
         flash(socket, :error, "Trait group already in #{socket.assigns.copy.noun_lower}")}

      {:error, :no_bullseye} ->
        {:noreply, flash(socket, :error, "Failed to create bullseye")}

      {:error, :include_group_required} ->
        {:noreply,
         flash(
           socket,
           :error,
           "Add a trait group that includes people first. An Anti-Trait Group only removes people from that."
         )}

      {:error, {:trait_in_both_roles, _}} ->
        {:noreply,
         flash(
           socket,
           :error,
           "That group shares an answer with a group of the opposite role on the bullseye."
         )}

      {:error, _} ->
        {:noreply, flash(socket, :error, "Failed to add trait group")}
    end
  end

  def handle_event(
        "remove_trait_group_from_bullseye",
        %{"band_id" => band_id, "trait_group_id" => trait_group_id},
        socket
      ) do
    case Targets.remove_trait_group_from_band(
           String.to_integer(band_id),
           String.to_integer(trait_group_id)
         ) do
      {:ok, _} ->
        {:noreply, changed(socket, "Trait group removed from bullseye")}

      {:error, :include_group_required} ->
        {:noreply,
         flash(
           socket,
           :error,
           "Remove the Anti-Trait Groups first. A bullseye needs a group that includes people."
         )}
    end
  end

  def handle_event("start_expanding_target", _params, socket) do
    {:noreply, assign(socket, :expanding_target, true)}
  end

  def handle_event("cancel_expanding_target", _params, socket) do
    {:noreply, assign(socket, :expanding_target, false)}
  end

  def handle_event("create_outer_band", %{"excluded_trait_group_id" => tg_id}, socket) do
    case Targets.create_outer_band(socket.assigns.target.id, String.to_integer(tg_id)) do
      {:ok, _band} ->
        {:noreply, changed(socket, "Ring created")}

      {:error, :cannot_create_empty_band} ->
        {:noreply, flash(socket, :error, "Cannot create empty band")}

      {:error, :include_group_required} ->
        {:noreply,
         flash(
           socket,
           :error,
           "A ring needs a group that includes people. Drop an Anti-Trait Group instead."
         )}

      {:error, _} ->
        {:noreply, flash(socket, :error, "Failed to create ring")}
    end
  end

  def handle_event("delete_outermost_band", _params, socket) do
    case Targets.delete_outermost_band(socket.assigns.target.id) do
      {:ok, _} ->
        {:noreply, changed(socket, "Ring deleted")}

      {:error, :cannot_delete_bullseye} ->
        {:noreply, flash(socket, :error, "Cannot delete bullseye")}

      {:error, _} ->
        {:noreply, flash(socket, :error, "No bands to delete")}
    end
  end

  def handle_event("populate_target", _params, socket) do
    Targets.trigger_population(socket.assigns.target)
    notify(:populating)
    {:noreply, socket}
  end

  def handle_event("done", _params, socket) do
    if socket.assigns.bands == [] do
      {:noreply, flash(socket, :error, socket.assigns.copy.done_empty)}
    else
      notify(:done)
      {:noreply, socket}
    end
  end

  def handle_event("open_suggestions", _params, socket) do
    {:noreply,
     socket
     |> assign(:review_open?, true)
     |> assign(:review_error, nil)
     |> assign(:review, new_review(socket.assigns))}
  end

  def handle_event("close_suggestions", _params, socket) do
    {:noreply, assign(socket, review_open?: false, review: nil, review_error: nil)}
  end

  def handle_event("review_change", params, socket) do
    review = socket.assigns.review

    selected =
      params
      |> Map.get("trait_ids", [])
      |> List.wrap()
      |> Enum.map(&String.to_integer/1)
      |> MapSet.new()

    titles =
      params
      |> Map.get("titles", %{})
      |> Map.new(fn {parent_id, title} -> {String.to_integer(parent_id), title} end)

    band_ids =
      case Map.get(params, "band_ids") do
        nil -> review.band_ids
        ids -> ids |> List.wrap() |> Enum.map(&String.to_integer/1)
      end

    {:noreply,
     assign(socket, :review, %{
       review
       | selected: selected,
         titles: Map.merge(review.titles, titles),
         shape: Map.get(params, "shape", review.shape),
         combined_title: Map.get(params, "combined_title", review.combined_title),
         band_ids: band_ids
     })}
  end

  def handle_event("select_topic", %{"parent_trait_id" => parent_id}, socket) do
    {:noreply, update_selection(socket, String.to_integer(parent_id), &MapSet.union/2)}
  end

  def handle_event("clear_topic", %{"parent_trait_id" => parent_id}, socket) do
    {:noreply, update_selection(socket, String.to_integer(parent_id), &MapSet.difference/2)}
  end

  def handle_event("dismiss_topic", %{"parent_trait_id" => parent_id}, socket) do
    {:ok, _} =
      AntiGroupSuggestions.dismiss(socket.assigns.target.id, String.to_integer(parent_id))

    {:noreply, load(socket)}
  end

  def handle_event("reopen_topic", %{"parent_trait_id" => parent_id}, socket) do
    :ok = AntiGroupSuggestions.reopen(socket.assigns.target.id, String.to_integer(parent_id))
    socket = load(socket)
    {:noreply, assign(socket, :review, new_review(socket.assigns))}
  end

  def handle_event("confirm_suggestions", _params, socket) do
    review = socket.assigns.review
    shape = if length(socket.assigns.suggestions.topics) > 1, do: review.shape, else: "per_topic"

    selections =
      for %{parent: parent, traits: traits} <- socket.assigns.suggestions.topics,
          ids = for(%{trait: t} <- traits, MapSet.member?(review.selected, t.id), do: t.id),
          ids != [] do
        %{
          parent_trait_id: parent.id,
          parent_name: parent.trait_name,
          trait_ids: ids,
          title: Map.get(review.titles, parent.id)
        }
      end

    case AntiGroupSuggestions.confirm(socket.assigns.target, selections, String.to_atom(shape),
           title: review.combined_title,
           band_ids: review.band_ids
         ) do
      {:ok, groups} ->
        noun = if length(groups) == 1, do: "Anti-Trait Group", else: "Anti-Trait Groups"

        {:noreply,
         socket
         |> assign(review_open?: false, review: nil, review_error: nil)
         |> changed("#{length(groups)} #{noun} added")}

      {:error, reason} ->
        {:noreply,
         assign(
           socket,
           :review_error,
           Targeting.topic_error(reason, socket.assigns.copy) |> error_text()
         )}
    end
  end

  defp update_selection(socket, parent_id, op) do
    review = socket.assigns.review

    topic_ids =
      socket.assigns.suggestions.topics
      |> Enum.filter(&(&1.parent.id == parent_id))
      |> Enum.flat_map(fn %{traits: traits} -> Enum.map(traits, & &1.trait.id) end)
      |> MapSet.new()

    assign(socket, :review, %{review | selected: op.(review.selected, topic_ids)})
  end

  defp error_text(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp error_text(text) when is_binary(text), do: text

  defp bullseye_or_create(target_id) do
    case Targets.get_bullseye_for_target(target_id) do
      nil ->
        case Targets.create_bullseye_band(target_id) do
          {:ok, band} -> {:ok, band}
          {:error, _} -> {:error, :no_bullseye}
        end

      band ->
        {:ok, band}
    end
  end

  defp changed(socket, message) do
    notify(:changed)
    socket |> flash(:info, message) |> load()
  end

  defp flash(socket, kind, message) do
    notify({:flash, kind, message})
    socket
  end

  defp notify(message), do: send(self(), {__MODULE__, message})

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <Targeting.band_editor
        copy={@copy}
        bands={@bands}
        outermost_band={@outermost_band}
        available_trait_groups={@available_trait_groups}
        me_file_counts={@me_file_counts}
        expanding_target={@expanding_target}
        phx_target={@myself}
      >
        <:notes>
          <Targeting.anti_suggestion_line
            suggestions={@suggestions}
            count={@suggestion_count}
            copy={@copy}
            phx_target={@myself}
          />
        </:notes>
      </Targeting.band_editor>

      <Targeting.suggestion_review
        :if={@review_open? and @review}
        suggestions={@suggestions}
        review={@review}
        bands={@bands}
        copy={@copy}
        error={@review_error}
        phx_target={@myself}
      />
    </div>
    """
  end
end
