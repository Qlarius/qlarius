defmodule QlariusWeb.Live.TraitGroupEditorComponent do
  @moduledoc """
  The single-topic trait group modal, owned once for every page that builds
  groups: marketer trait groups, creator trait groups, and the creator audience
  starter.

  A parent opens it by passing `parent_trait_id` and closes it with `nil`. The
  component loads the parent trait with its answers, holds the form, the chosen
  answers, the zip selector, and saves through `on_save`. The default `on_save`
  creates a group for `owner`.

  Messages sent to the parent LiveView:

    * `{__MODULE__, :saved, result}` after `on_save` returns `{:ok, result}`
    * `{__MODULE__, :closed}` when the person cancels
    * `{__MODULE__, :failed, message}` when the parent trait cannot be opened

  ## Assigns

    * `:id` — DOM id
    * `:owner` — `{:marketer, id}` or `{:creator, id}`
    * `:parent_trait_id` — the topic to edit, or `nil` to stay closed
    * `:group_id` — the group being edited, so switching groups on the same
      topic reopens with fresh state (optional)
    * `:preselected_ids` — answer ids that start checked (optional)
    * `:title`, `:description` — initial group fields (optional)
    * `:heading`, `:submit_label` — modal copy (optional)
    * `:zip_seed` — `%{label, codes}` zip codes held under another topic, offered
      as a starting point for a new zip topic (optional)
    * `:on_save` — `fn %{title, description, parent_trait_id, trait_ids} -> {:ok, _} | {:error, _}`
  """

  use QlariusWeb, :live_component

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.TraitGroup
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait
  alias QlariusWeb.Components.Targeting

  @form_id "trait-group-form"

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       open?: false,
       open_key: nil,
       group_id: nil,
       parent_trait: nil,
       preselected_ids: [],
       title: nil,
       description: nil,
       heading: nil,
       submit_label: "Create Trait Group",
       zip_seed: nil,
       on_save: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    requested = Map.get(assigns, :parent_trait_id)
    socket = assign(socket, assigns)
    key = {requested, Map.get(assigns, :group_id)}

    cond do
      is_nil(requested) ->
        {:ok, close(socket)}

      socket.assigns.open? and socket.assigns.open_key == key ->
        {:ok, socket}

      true ->
        {:ok, open(socket, requested, key)}
    end
  end

  defp open(socket, parent_trait_id, key) do
    case Traits.get_trait_with_full_survey_data!(parent_trait_id) do
      {:ok, trait} ->
        preselected = socket.assigns.preselected_ids || []

        socket
        |> assign(:open?, true)
        |> assign(:open_key, key)
        |> assign(:parent_trait, trait)
        |> assign(
          :form,
          build_form(%{
            "title" => socket.assigns.title || "",
            "description" => socket.assigns.description || ""
          })
        )
        |> assign(:selected_ids, preselected)
        |> assign(:selected_zips, preselected_zips(trait, preselected))
        |> assign(:zip_search_term, "")
        |> assign(:zip_search_results, [])
        |> assign(:zip_search_limit, 1000)
        |> assign(:error, nil)

      {:error, _} ->
        send(self(), {__MODULE__, :failed, "Selected trait is not a parent trait"})
        close(socket)
    end
  end

  defp close(socket), do: assign(socket, open?: false, open_key: nil, parent_trait: nil)

  defp preselected_zips(%{input_type: "single_select_zip"}, [_ | _] = ids) do
    from(t in Trait,
      where: t.id in ^ids,
      select: %{id: t.id, zip_code: t.trait_name, location: t.meta_1}
    )
    |> Repo.all()
    |> sort_zips()
  end

  defp preselected_zips(_trait, _ids), do: []

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), {__MODULE__, :closed})
    {:noreply, close(socket)}
  end

  def handle_event("validate_trait_group", params, socket) do
    socket = assign(socket, :selected_ids, Targeting.trait_ids_from_params(params))

    case List.first(List.wrap(params["_target"])) do
      "search" -> {:noreply, assign_zip_search(socket, params)}
      "trait_group" -> {:noreply, assign_form(socket, params)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("change_zip_limit", %{"limit" => limit_value}, socket) do
    limit = if limit_value == "all", do: :all, else: String.to_integer(limit_value)

    {:noreply,
     socket
     |> assign(:zip_search_limit, limit)
     |> refresh_zip_results()}
  end

  def handle_event("save_trait_group", %{"trait_group" => params, "trait_ids" => ids}, socket) do
    ids = ids |> List.wrap() |> Enum.map(&String.to_integer/1)
    save(socket, params, ids)
  end

  def handle_event("save_trait_group", %{"trait_group" => params}, socket) do
    if zip_parent?(socket) do
      save(socket, params, Enum.map(socket.assigns.selected_zips, & &1.id))
    else
      save(socket, params, [])
    end
  end

  def handle_event("add_selected_zips", %{"selected_ids" => selected_ids}, socket) do
    ids = selected_ids |> List.wrap() |> Enum.map(&String.to_integer/1)

    new_zips =
      from(t in Trait,
        where: t.id in ^ids,
        select: %{id: t.id, zip_code: t.trait_name, location: t.meta_1}
      )
      |> Repo.all()

    {:noreply, add_zips(socket, new_zips)}
  end

  def handle_event("add_selected_zips", _params, socket), do: {:noreply, socket}

  def handle_event("add_all_visible_zips", _params, socket) do
    visible =
      Traits.search_zip_codes(
        socket.assigns.parent_trait.id,
        socket.assigns.zip_search_term,
        socket.assigns.zip_search_limit
      )

    {:noreply, add_zips(socket, visible)}
  end

  def handle_event("remove_selected_zips", %{"selected_ids" => selected_ids}, socket) do
    ids = selected_ids |> List.wrap() |> Enum.map(&String.to_integer/1)
    remaining = Enum.reject(socket.assigns.selected_zips, &(&1.id in ids))
    {:noreply, assign(socket, :selected_zips, remaining)}
  end

  def handle_event("remove_selected_zips", _params, socket), do: {:noreply, socket}

  def handle_event("clear_all_zips", _params, socket) do
    {:noreply, assign(socket, :selected_zips, [])}
  end

  def handle_event("seed_zips", _params, socket) do
    case socket.assigns.zip_seed do
      %{codes: [_ | _] = codes} ->
        parent_id = socket.assigns.parent_trait.id

        zips =
          from(t in Trait,
            where: t.parent_trait_id == ^parent_id and t.trait_name in ^codes,
            select: %{id: t.id, zip_code: t.trait_name, location: t.meta_1}
          )
          |> Repo.all()

        {:noreply, add_zips(socket, zips)}

      _ ->
        {:noreply, socket}
    end
  end

  defp save(socket, params, []) do
    message =
      if zip_parent?(socket),
        do: "Select at least one zip code",
        else: "Select at least one answer"

    {:noreply,
     socket
     |> assign(:form, build_form(params, :validate))
     |> assign(:error, message)}
  end

  defp save(socket, params, trait_ids) do
    attrs = %{
      title: params["title"],
      description: params["description"],
      parent_trait_id: socket.assigns.parent_trait.id,
      trait_ids: trait_ids,
      role: role_param(socket, params)
    }

    saver = socket.assigns.on_save || (&default_save(&1, socket.assigns.owner))

    case saver.(attrs) do
      {:ok, result} ->
        send(self(), {__MODULE__, :saved, result})
        {:noreply, close(socket)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset, as: :trait_group, id: @form_id))
         |> assign(:error, nil)}

      {:error, message} when is_binary(message) ->
        {:noreply, assign(socket, :error, message)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Could not save: #{inspect(reason)}")}
    end
  end

  defp default_save(attrs, owner) do
    attrs
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.merge(owner_attrs(owner))
    |> Traits.create_trait_group()
  end

  defp owner_attrs({:marketer, id}), do: %{"marketer_id" => id}
  defp owner_attrs({:creator, id}), do: %{"creator_id" => id}

  # The role is chosen once, when the component creates a new group itself.
  # Topic edits and custom savers never change it.
  defp role_choice?(%{on_save: on_save, group_id: group_id}),
    do: is_nil(on_save) and is_nil(group_id)

  defp role_param(socket, params) do
    if role_choice?(socket.assigns) and role_value(params) == "anti",
      do: "anti",
      else: "include"
  end

  # A hidden "include" precedes the checkbox, so Phoenix may deliver a list.
  defp role_value(params), do: params |> Map.get("role") |> List.wrap() |> List.last()

  defp assign_form(socket, params) do
    assign(socket, :form, build_form(Map.get(params, "trait_group", %{}), :validate))
  end

  defp build_form(params, action \\ nil) do
    %TraitGroup{}
    |> TraitGroup.changeset(params)
    |> Map.put(:action, action)
    |> to_form(as: :trait_group, id: @form_id)
  end

  defp assign_zip_search(socket, params) do
    term = params |> Map.get("search", "") |> to_string() |> String.trim()

    socket
    |> assign_form(params)
    |> assign(:zip_search_term, term)
    |> refresh_zip_results()
  end

  defp refresh_zip_results(socket) do
    term = socket.assigns.zip_search_term

    results =
      if zip_parent?(socket) and String.length(term) >= 2 do
        Traits.search_zip_codes(
          socket.assigns.parent_trait.id,
          term,
          socket.assigns.zip_search_limit
        )
      else
        []
      end

    assign(socket, :zip_search_results, results)
  end

  defp add_zips(socket, zips) do
    merged =
      (socket.assigns.selected_zips ++ zips)
      |> Enum.uniq_by(& &1.id)
      |> sort_zips()

    assign(socket, :selected_zips, merged)
  end

  defp sort_zips(zips) do
    Enum.sort_by(zips, fn zip ->
      case Integer.parse(zip.zip_code) do
        {n, ""} -> n
        _ -> 99_999
      end
    end)
  end

  defp zip_parent?(socket) do
    match?(%{input_type: "single_select_zip"}, socket.assigns.parent_trait)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <Targeting.trait_group_modal
        :if={@open?}
        show_modal={@open?}
        parent_trait={@parent_trait}
        form={@form}
        zip_search_term={@zip_search_term}
        zip_search_results={@zip_search_results}
        selected_zips={@selected_zips}
        zip_search_limit={@zip_search_limit}
        heading={@heading}
        submit_label={@submit_label}
        selected_ids={@selected_ids}
        error={@error}
        zip_seed={@zip_seed}
        role_choice?={role_choice?(assigns)}
        phx_target={@myself}
      />
    </div>
    """
  end
end
