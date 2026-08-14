defmodule QlariusWeb.Creators.LinkInBioMigrationLive do
  @moduledoc """
  Admin wizard to migrate a public link-in-bio page into a draft Qlink page.

  Flow: `:destination` → `:source` → `:review` → `:importing` → `:done`.
  """

  use QlariusWeb, :live_view

  alias Qlarius.Creators
  alias Qlarius.Qlink
  alias Qlarius.Qlink.LinkInBio.Draft
  alias Qlarius.Qlink.LinkInBioImporter
  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}

  @wizard_step_order [:destination, :source, :review, :importing, :done]

  @impl true
  def mount(_params, _session, socket) do
    creators = Creators.list_creators()

    {:ok,
     assign(socket,
       page_title: "Link-in-bio Migration",
       wizard_step: :destination,
       creators: creators,
       creator_mode: :existing,
       selected_creator_id: nil,
       new_creator_name: "",
       creator: nil,
       creator_error: nil,
       source_url: "",
       fetch_error: nil,
       fetching?: false,
       draft: nil,
       review_alias: "",
       review_title: "",
       review_bio: "",
       alias_warning: nil,
       importing?: false,
       import_error: nil,
       imported_page: nil
     )}
  end

  @impl true
  def handle_event("set_creator_mode", %{"mode" => mode}, socket) do
    mode = if mode == "new", do: :new, else: :existing
    {:noreply, assign(socket, creator_mode: mode, creator_error: nil)}
  end

  def handle_event("select_creator", %{"creator_id" => id}, socket) do
    {:noreply, assign(socket, selected_creator_id: id, creator_error: nil)}
  end

  def handle_event("update_new_creator_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, new_creator_name: name, creator_error: nil)}
  end

  def handle_event("continue_destination", _params, socket) do
    case resolve_creator(socket) do
      {:ok, creator} ->
        {:noreply,
         assign(socket,
           creator: creator,
           wizard_step: :source,
           creator_error: nil
         )}

      {:error, message} ->
        {:noreply, assign(socket, creator_error: message)}
    end
  end

  def handle_event("back_to_destination", _params, socket) do
    {:noreply,
     assign(socket,
       wizard_step: :destination,
       draft: nil,
       fetch_error: nil,
       source_url: socket.assigns.source_url
     )}
  end

  def handle_event("update_source_url", %{"url" => url}, socket) do
    {:noreply, assign(socket, source_url: url, fetch_error: nil)}
  end

  def handle_event("fetch_preview", _params, socket) do
    url = socket.assigns.source_url

    socket =
      socket
      |> assign(fetching?: true, fetch_error: nil)
      |> start_async(:fetch, fn -> LinkInBioImporter.fetch_preview(url) end)

    {:noreply, socket}
  end

  def handle_event("back_to_source", _params, socket) do
    {:noreply,
     assign(socket,
       wizard_step: :source,
       draft: nil,
       import_error: nil
     )}
  end

  def handle_event("update_review", params, socket) do
    alias_ = Map.get(params, "alias", socket.assigns.review_alias)
    title = Map.get(params, "title", socket.assigns.review_title)
    bio = Map.get(params, "bio", socket.assigns.review_bio)

    {:noreply,
     assign(socket,
       review_alias: alias_,
       review_title: title,
       review_bio: bio,
       alias_warning: alias_availability_warning(alias_)
     )}
  end

  def handle_event("toggle_link", %{"section" => s_idx, "link" => l_idx}, socket) do
    s_idx = String.to_integer(s_idx)
    l_idx = String.to_integer(l_idx)
    draft = socket.assigns.draft

    sections =
      Enum.with_index(draft.sections)
      |> Enum.map(fn {section, si} ->
        if si == s_idx do
          links =
            Enum.with_index(section.links)
            |> Enum.map(fn {link, li} ->
              if li == l_idx, do: Map.put(link, :include?, !link[:include?]), else: link
            end)

          %{section | links: links}
        else
          section
        end
      end)

    {:noreply, assign(socket, draft: %{draft | sections: sections})}
  end

  def handle_event("start_import", _params, socket) do
    draft = socket.assigns.draft
    creator = socket.assigns.creator

    alias_ = Draft.sanitize_alias(socket.assigns.review_alias) || draft.suggested_alias
    title = String.trim(socket.assigns.review_title || "")
    bio = String.trim(socket.assigns.review_bio || "")

    if Draft.included_links(draft) == [] do
      {:noreply, put_flash(socket, :error, "Include at least one link to import.")}
    else
      opts = [
        alias: alias_,
        title: if(title == "", do: nil, else: title),
        bio_text: if(bio == "", do: nil, else: bio),
        sections: draft.sections
      ]

      socket =
        socket
        |> assign(wizard_step: :importing, importing?: true, import_error: nil)
        |> start_async(:import, fn -> LinkInBioImporter.import!(draft, creator, opts) end)

      {:noreply, socket}
    end
  end

  def handle_event("edit_page", _params, socket) do
    page = socket.assigns.imported_page
    {:noreply, push_navigate(socket, to: ~p"/creators/qlink_pages/#{page.id}/edit")}
  end

  def handle_event("start_over", _params, socket) do
    {:noreply,
     assign(socket,
       wizard_step: :destination,
       creator: nil,
       selected_creator_id: nil,
       new_creator_name: "",
       source_url: "",
       draft: nil,
       fetch_error: nil,
       import_error: nil,
       imported_page: nil,
       review_alias: "",
       review_title: "",
       review_bio: "",
       alias_warning: nil
     )}
  end

  @impl true
  def handle_async(:fetch, {:ok, {:ok, draft}}, socket) do
    {:noreply,
     assign(socket,
       fetching?: false,
       wizard_step: :review,
       draft: draft,
       review_alias: draft.suggested_alias || "",
       review_title: draft.title || "",
       review_bio: draft.bio_text || "",
       alias_warning: alias_availability_warning(draft.suggested_alias)
     )}
  end

  def handle_async(:fetch, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, fetching?: false, fetch_error: format_error(reason))}
  end

  def handle_async(:fetch, {:exit, reason}, socket) do
    {:noreply, assign(socket, fetching?: false, fetch_error: "Fetch crashed: #{inspect(reason)}")}
  end

  def handle_async(:import, {:ok, {:ok, page}}, socket) do
    {:noreply,
     assign(socket,
       importing?: false,
       wizard_step: :done,
       imported_page: page
     )}
  end

  def handle_async(:import, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       importing?: false,
       wizard_step: :review,
       import_error: format_error(reason)
     )}
  end

  def handle_async(:import, {:exit, reason}, socket) do
    {:noreply,
     assign(socket,
       importing?: false,
       wizard_step: :review,
       import_error: "Import crashed: #{inspect(reason)}"
     )}
  end

  defp resolve_creator(%{assigns: %{creator_mode: :existing, selected_creator_id: id}})
       when is_binary(id) and id != "" do
    case Integer.parse(id) do
      {int_id, _} ->
        {:ok, Creators.get_creator!(int_id)}

      :error ->
        {:error, "Select a creator."}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Creator not found."}
  end

  defp resolve_creator(%{assigns: %{creator_mode: :existing}}),
    do: {:error, "Select a creator."}

  defp resolve_creator(%{assigns: %{creator_mode: :new, new_creator_name: name}}) do
    name = String.trim(name || "")

    if name == "" do
      {:error, "Enter a creator name."}
    else
      case Creators.create_creator(%{"name" => name}) do
        {:ok, creator} -> {:ok, creator}
        {:error, changeset} -> {:error, format_changeset(changeset)}
      end
    end
  end

  defp alias_availability_warning(nil), do: nil

  defp alias_availability_warning(alias_) do
    sanitized = Draft.sanitize_alias(alias_)

    cond do
      is_nil(sanitized) or String.length(sanitized) < 3 ->
        "Alias must be at least 3 characters (lowercase letters, numbers, _ or -)."

      not Qlink.alias_available?(sanitized) ->
        "Alias \"#{sanitized}\" is taken — import will append a suffix."

      true ->
        nil
    end
  end

  defp format_error(%Ecto.Changeset{} = cs), do: format_changeset(cs)
  defp format_error({:http_status, status}), do: "HTTP #{status} fetching page"
  defp format_error({:fetch_failed, msg}), do: "Fetch failed: #{msg}"
  defp format_error(:empty_url), do: "Enter a source URL."
  defp format_error(:no_owner_user), do: "Could not provision tip recipient for this creator."
  defp format_error(other), do: inspect(other)

  defp format_changeset(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        atom_key = String.to_atom(key)
        opts |> Keyword.get(atom_key, key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  def step_at_or_past?(current, target) do
    current_idx = Enum.find_index(@wizard_step_order, &(&1 == current)) || 0
    target_idx = Enum.find_index(@wizard_step_order, &(&1 == target)) || 0
    current_idx >= target_idx
  end

  def platform_label(:linktree), do: "Linktree"
  def platform_label(:beacons), do: "Beacons"
  def platform_label(:generic), do: "Generic"
  def platform_label(_), do: "Unknown"

  def public_qlink_url(alias_) when is_binary(alias_) and alias_ != "" do
    "https://qlinkin.bio/@#{alias_}"
  end

  def public_qlink_url(_), do: nil

  def link_count(%Draft{} = draft) do
    draft.sections
    |> Enum.flat_map(& &1.links)
    |> length()
  end

  def included_count(%Draft{} = draft), do: length(Draft.included_links(draft))
end
