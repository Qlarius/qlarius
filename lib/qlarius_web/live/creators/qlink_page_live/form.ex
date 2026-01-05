defmodule QlariusWeb.Creators.QlinkPageLive.Form do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Qlink
  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkLink
  alias Qlarius.Qlink.QlinkSection
  alias Qlarius.Creators
  alias Qlarius.Repo
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    page = Qlink.get_page!(id) |> Repo.preload(:creator)
    creator = page.creator

    links = Qlink.list_page_links(page.id) |> Repo.preload(:qlink_section)
    sections = Qlink.list_page_sections(page.id)

    changeset = Qlink.change_page(page)
    social_links_map = if(is_map(page.social_links), do: page.social_links, else: %{})

    social_links_list =
      Enum.map(social_links_map, fn {platform, url} ->
        %{id: "social-#{System.unique_integer([:positive])}", platform: platform, url: url}
      end)

    used_platforms = MapSet.new(Map.keys(social_links_map))

    socket
    |> assign(page: page, creator: creator)
    |> assign(
      form: to_form(changeset),
      page_title: "Edit Qlink Page",
      links: links,
      sections: sections,
      show_link_modal: false,
      editing_link: nil,
      link_form: nil,
      show_section_modal: false,
      editing_section: nil,
      section_form: nil,
      selected_social_platform: "",
      used_social_platforms: used_platforms,
      social_links: social_links_list,
      social_links_data: social_links_map
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  @impl true
  def handle_params(%{"creator_id" => creator_id}, _uri, socket) do
    creator = Creators.get_creator!(creator_id)
    changeset = Qlink.change_page(%QlinkPage{})

    socket
    |> assign(
      page: %QlinkPage{},
      creator: creator,
      form: to_form(changeset),
      page_title: "New Qlink Page",
      links: [],
      sections: [],
      show_link_modal: false,
      editing_link: nil,
      link_form: nil,
      show_section_modal: false,
      editing_section: nil,
      section_form: nil,
      social_links: [],
      social_links_data: %{},
      selected_social_platform: "",
      used_social_platforms: MapSet.new()
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"qlink_page" => page_params} = _params, socket) do
    page_params = normalize_social_links_params(page_params, socket.assigns.social_links_data)

    changeset =
      socket.assigns.page
      |> Qlink.change_page(page_params)
      |> Map.put(:action, :validate)

    changeset =
      if socket.assigns.live_action == :new do
        alias = get_in(page_params, ["alias"])

        if alias && String.length(alias) >= 3 do
          if Qlink.alias_available?(alias) do
            changeset
          else
            Ecto.Changeset.add_error(changeset, :alias, "is already taken")
          end
        else
          changeset
        end
      else
        changeset
      end

    form = to_form(changeset)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_social_platform", params, socket) do
    platform = Map.get(params, "selected_social_platform", "") || ""
    {:noreply, assign(socket, :selected_social_platform, platform)}
  end

  @impl true
  def handle_event("ignore", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_social_link", params, socket) do
    id = Map.get(params, "id") || extract_id_from_params(params)

    if id do
      social_links_params = Map.get(params, "social_links", %{})
      link_params = Map.get(social_links_params, id, %{})
      url = String.trim(Map.get(link_params, "url", ""))

      updated_link = Enum.find(socket.assigns.social_links, &(&1.id == id))

      if updated_link do
        platform = updated_link.platform

        social_links =
          Enum.map(socket.assigns.social_links, fn link ->
            if link.id == id do
              %{link | url: url}
            else
              link
            end
          end)

        social_links_data = Map.put(socket.assigns.social_links_data, platform, url)

        socket
        |> assign(:social_links, social_links)
        |> assign(:social_links_data, social_links_data)
        |> noreply()
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_selected_social_link", _params, socket) do
    platform = socket.assigns.selected_social_platform

    if platform && platform != "" do
      id = "social-#{System.unique_integer([:positive])}"
      used_platforms = MapSet.put(socket.assigns.used_social_platforms, platform)
      new_link = %{id: id, platform: platform, url: ""}
      social_links = [new_link | socket.assigns.social_links]
      social_links_data = Map.put(socket.assigns.social_links_data, platform, "")

      socket
      |> assign(:selected_social_platform, "")
      |> assign(:used_social_platforms, used_platforms)
      |> assign(:social_links, social_links)
      |> assign(:social_links_data, social_links_data)
      |> noreply()
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_social_link", %{"id" => id}, socket) do
    entry = Enum.find(socket.assigns.social_links, &(&1.id == id))

    {used_platforms, social_links, social_links_data} =
      if entry do
        platform = entry.platform

        {
          MapSet.delete(socket.assigns.used_social_platforms, platform),
          Enum.reject(socket.assigns.social_links, &(&1.id == id)),
          Map.delete(socket.assigns.social_links_data, platform)
        }
      else
        {socket.assigns.used_social_platforms, socket.assigns.social_links,
         socket.assigns.social_links_data}
      end

    socket
    |> assign(:used_social_platforms, used_platforms)
    |> assign(:social_links, social_links)
    |> assign(:social_links_data, social_links_data)
    |> noreply()
  end

  @impl true
  def handle_event("save", %{"qlink_page" => page_params} = all_params, socket) do
    save_page(socket, socket.assigns.live_action, page_params, all_params)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event("delete_image", _params, socket) do
    case delete_qlink_page_image(socket.assigns.page) do
      {:ok, page} ->
        changeset = Qlink.change_page(page)

        socket
        |> assign(page: page)
        |> assign(form: to_form(changeset))
        |> put_flash(:info, "Image deleted successfully")
        |> noreply()

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete image")}
    end
  end

  @impl true
  def handle_event("show_add_link_modal", _params, socket) do
    if socket.assigns.page.id do
      max_order = get_max_display_order(socket.assigns.links)

      changeset =
        Qlink.change_link(%QlinkLink{}, %{
          qlink_page_id: socket.assigns.page.id,
          type: :standard,
          display_order: max_order + 1,
          is_visible: true
        })

      socket
      |> assign(show_link_modal: true, editing_link: nil, link_form: to_form(changeset))
      |> noreply()
    else
      {:noreply, put_flash(socket, :error, "Please save the page first before adding links")}
    end
  end

  @impl true
  def handle_event("show_edit_link_modal", %{"id" => id}, socket) do
    link = Qlink.get_link!(id) |> Repo.preload(:qlink_section)
    changeset = Qlink.change_link(link, %{})

    socket
    |> assign(show_link_modal: true, editing_link: link, link_form: to_form(changeset))
    |> noreply()
  end

  @impl true
  def handle_event("close_link_modal", _params, socket) do
    socket
    |> assign(show_link_modal: false, editing_link: nil, link_form: nil)
    |> noreply()
  end

  @impl true
  def handle_event("validate_link", %{"qlink_link" => link_params}, socket) do
    link = socket.assigns.editing_link || %QlinkLink{qlink_page_id: socket.assigns.page.id}

    link_params = detect_embed_type(link_params)

    changeset = Qlink.change_link(link, link_params)

    socket
    |> assign(link_form: to_form(changeset))
    |> noreply()
  end

  @impl true
  def handle_event("save_link", %{"qlink_link" => link_params}, socket) do
    link_params =
      link_params
      |> normalize_link_params()
      |> detect_embed_type()

    result =
      if socket.assigns.editing_link do
        Qlink.update_link(socket.assigns.editing_link, link_params)
      else
        max_order = get_max_display_order(socket.assigns.links)

        final_params =
          link_params
          |> Map.put("qlink_page_id", socket.assigns.page.id)
          |> Map.put("display_order", max_order + 1)

        require Logger
        Logger.debug("Creating link with params: #{inspect(final_params)}")

        Qlink.create_link(final_params)
      end

    case result do
      {:ok, link} ->
        require Logger
        Logger.debug("Link created successfully: #{inspect(link.id)}")

        links = Qlink.list_page_links(socket.assigns.page.id) |> Repo.preload(:qlink_section)

        socket
        |> assign(links: links, show_link_modal: false, editing_link: nil, link_form: nil)
        |> put_flash(:info, "Link saved successfully")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("Failed to save link. Errors: #{inspect(changeset.errors)}")
        Logger.error("Changeset changes: #{inspect(changeset.changes)}")
        Logger.error("Changeset data: #{inspect(changeset.data)}")

        socket
        |> assign(show_link_modal: true, link_form: to_form(changeset, action: :validate))
        |> put_flash(:error, "Failed to save link. Please check the form for errors.")
        |> noreply()
    end
  end

  @impl true
  def handle_event("delete_link", %{"id" => id}, socket) do
    link = Qlink.get_link!(id)

    case Qlink.delete_link(link) do
      {:ok, _link} ->
        links = Qlink.list_page_links(socket.assigns.page.id) |> Repo.preload(:qlink_section)

        socket
        |> assign(links: links)
        |> put_flash(:info, "Link deleted successfully")
        |> noreply()

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete link")}
    end
  end

  @impl true
  def handle_event("show_add_section_modal", _params, socket) do
    if socket.assigns.page.id do
      max_order = get_max_section_order(socket.assigns.sections)

      changeset =
        Qlink.change_section(%QlinkSection{}, %{
          qlink_page_id: socket.assigns.page.id,
          display_order: max_order + 1,
          is_collapsed: false
        })

      socket
      |> assign(show_section_modal: true, editing_section: nil, section_form: to_form(changeset))
      |> noreply()
    else
      {:noreply, put_flash(socket, :error, "Please save the page first before adding sections")}
    end
  end

  @impl true
  def handle_event("show_edit_section_modal", %{"id" => id}, socket) do
    section = Qlink.get_section!(id)
    changeset = Qlink.change_section(section, %{})

    socket
    |> assign(
      show_section_modal: true,
      editing_section: section,
      section_form: to_form(changeset)
    )
    |> noreply()
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    socket
    |> assign(show_section_modal: false, editing_section: nil, section_form: nil)
    |> noreply()
  end

  @impl true
  def handle_event("validate_section", %{"qlink_section" => section_params}, socket) do
    section =
      socket.assigns.editing_section || %QlinkSection{qlink_page_id: socket.assigns.page.id}

    changeset = Qlink.change_section(section, section_params)

    socket
    |> assign(section_form: to_form(changeset))
    |> noreply()
  end

  @impl true
  def handle_event("save_section", %{"qlink_section" => section_params}, socket) do
    result =
      if socket.assigns.editing_section do
        Qlink.update_section(socket.assigns.editing_section, section_params)
      else
        max_order = get_max_section_order(socket.assigns.sections)

        section_params
        |> Map.put("qlink_page_id", socket.assigns.page.id)
        |> Map.put("display_order", max_order + 1)
        |> then(&Qlink.create_section/1)
      end

    case result do
      {:ok, _section} ->
        sections = Qlink.list_page_sections(socket.assigns.page.id)

        socket
        |> assign(
          sections: sections,
          show_section_modal: false,
          editing_section: nil,
          section_form: nil
        )
        |> put_flash(:info, "Section saved successfully")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        socket
        |> assign(show_section_modal: true, section_form: to_form(changeset, action: :validate))
        |> put_flash(:error, "Failed to save section. Please check the form for errors.")
        |> noreply()
    end
  end

  @impl true
  def handle_event("delete_section", %{"id" => id}, socket) do
    section = Qlink.get_section!(id)

    case Qlink.delete_section(section) do
      {:ok, _section} ->
        sections = Qlink.list_page_sections(socket.assigns.page.id)

        socket
        |> assign(sections: sections)
        |> put_flash(:info, "Section deleted successfully")
        |> noreply()

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_event("move_section", %{"id" => id, "direction" => direction}, socket) do
    section = Qlink.get_section!(id)
    sections = socket.assigns.sections

    case calculate_section_order(section, sections, direction) do
      {:ok, updated_sections} ->
        socket
        |> assign(sections: updated_sections)
        |> noreply()

      :no_change ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reorder section")}
    end
  end

  @impl true
  def handle_event("move_link", %{"id" => id, "direction" => direction}, socket) do
    link = Qlink.get_link!(id)
    links = socket.assigns.links

    case calculate_new_order(link, links, direction) do
      {:ok, updated_links} ->
        socket
        |> assign(links: updated_links)
        |> noreply()

      :no_change ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reorder link")}
    end
  end

  defp delete_qlink_page_image(%QlinkPage{} = page) do
    if page.profile_photo do
      CreatorImage.delete({page.profile_photo, page})
      Qlink.update_page(page, %{profile_photo: nil})
    else
      {:ok, page}
    end
  end

  defp delete_qlink_page_image(_), do: {:error, :not_found}

  defp save_page(socket, :edit, page_params, _all_params) do
    filename = ImageUpload.consume_upload(socket, :image, socket.assigns.page, CreatorImage)

    page_params_with_image =
      if filename, do: Map.put(page_params, "profile_photo", filename), else: page_params

    require Logger

    Logger.debug(
      "save_page :edit - social_links_data assign: #{inspect(socket.assigns.social_links_data)}"
    )

    social_links_map =
      socket.assigns.social_links_data
      |> Enum.filter(fn {_platform, url} -> url != "" end)
      |> Enum.into(%{})

    Logger.debug("save_page :edit - filtered social_links_map: #{inspect(social_links_map)}")

    page_params_with_image = Map.put(page_params_with_image, "social_links", social_links_map)

    case Qlink.update_page(socket.assigns.page, page_params_with_image) do
      {:ok, page} ->
        socket
        |> put_flash(:info, "Qlink page updated successfully")
        |> push_navigate(to: ~p"/creators/#{page.creator_id}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
        |> noreply()
    end
  end

  defp save_page(socket, :new, page_params, _all_params) do
    creator = socket.assigns.creator
    temp_page = %QlinkPage{creator_id: creator.id}

    filename = ImageUpload.consume_upload(socket, :image, temp_page, CreatorImage)

    page_params_with_image =
      if filename, do: Map.put(page_params, "profile_photo", filename), else: page_params

    social_links_map =
      socket.assigns.social_links_data
      |> Enum.filter(fn {_platform, url} -> url != "" end)
      |> Enum.into(%{})

    page_params_with_image = Map.put(page_params_with_image, "social_links", social_links_map)

    page_params_with_image =
      page_params_with_image
      |> Map.put("creator_id", creator.id)
      |> Map.put("slug", page_params_with_image["alias"] || "")

    case Qlink.create_page(page_params_with_image) do
      {:ok, page} ->
        socket
        |> put_flash(:info, "Qlink page created successfully")
        |> push_navigate(to: ~p"/creators/qlink_pages/#{page.id}/edit")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
        |> noreply()
    end
  end

  defp normalize_social_links_params(page_params, social_links_data) do
    social_links_map =
      social_links_data
      |> Enum.filter(fn {_platform, url} -> url != "" end)
      |> Enum.into(%{})

    Map.put(page_params, "social_links", social_links_map)
  end

  def available_social_platforms(used_platforms) do
    all_platforms = [
      "twitter",
      "instagram",
      "facebook",
      "linkedin",
      "youtube",
      "tiktok",
      "github"
    ]

    all_platforms
    |> Enum.reject(&MapSet.member?(used_platforms, &1))
  end

  def format_platform_name("twitter"), do: "Twitter/X"
  def format_platform_name("instagram"), do: "Instagram"
  def format_platform_name("facebook"), do: "Facebook"
  def format_platform_name("linkedin"), do: "LinkedIn"
  def format_platform_name("youtube"), do: "YouTube"
  def format_platform_name("tiktok"), do: "TikTok"
  def format_platform_name("github"), do: "GitHub"
  def format_platform_name(platform), do: String.capitalize(platform || "")

  defp extract_id_from_params(params) do
    case Map.get(params, "_target") do
      ["social_links", id | _] ->
        id

      _ ->
        social_links = Map.get(params, "social_links", %{})

        case Map.keys(social_links) do
          [id | _] -> id
          _ -> nil
        end
    end
  end

  defp normalize_link_params(link_params) do
    link_params
    |> Map.update("qlink_section_id", nil, fn
      "" -> nil
      id -> id
    end)
    |> Map.update("is_visible", true, fn
      "true" -> true
      "false" -> false
      val -> val
    end)
  end

  defp detect_embed_type(link_params) do
    url = Map.get(link_params, "url", "")

    if embed_config = QlinkLink.parse_embed_config(url) do
      link_params
      |> Map.put("type", "embed")
      |> Map.put("embed_config", embed_config)
    else
      link_params
    end
  end

  defp get_max_display_order(links) do
    case links do
      [] -> 0
      links -> Enum.max_by(links, & &1.display_order, fn -> %{display_order: 0} end).display_order
    end
  end

  defp get_max_section_order(sections) do
    case sections do
      [] ->
        0

      sections ->
        Enum.max_by(sections, & &1.display_order, fn -> %{display_order: 0} end).display_order
    end
  end

  defp calculate_section_order(section, sections, direction) do
    sorted_sections = Enum.sort_by(sections, & &1.display_order)
    current_index = Enum.find_index(sorted_sections, &(&1.id == section.id))

    case {direction, current_index} do
      {"up", index} when not is_nil(index) and index > 0 ->
        prev_section = Enum.at(sorted_sections, index - 1)
        swap_section_orders(section, prev_section)

      {"down", index} when not is_nil(index) and index < length(sorted_sections) - 1 ->
        next_section = Enum.at(sorted_sections, index + 1)
        swap_section_orders(section, next_section)

      _ ->
        :no_change
    end
  end

  defp swap_section_orders(section1, section2) do
    temp_order = section1.display_order

    case Qlink.update_section(section1, %{display_order: section2.display_order}) do
      {:ok, _} ->
        case Qlink.update_section(section2, %{display_order: temp_order}) do
          {:ok, _} ->
            updated_sections = Qlink.list_page_sections(section1.qlink_page_id)
            {:ok, updated_sections}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_new_order(link, links, direction) do
    same_section_links =
      links
      |> Enum.filter(fn l -> l.qlink_section_id == link.qlink_section_id end)
      |> Enum.sort_by(& &1.display_order)

    current_index = Enum.find_index(same_section_links, &(&1.id == link.id))

    case {direction, current_index} do
      {"up", index} when not is_nil(index) and index > 0 ->
        prev_link = Enum.at(same_section_links, index - 1)
        swap_display_orders(link, prev_link)

      {"down", index} when not is_nil(index) and index < length(same_section_links) - 1 ->
        next_link = Enum.at(same_section_links, index + 1)
        swap_display_orders(link, next_link)

      _ ->
        :no_change
    end
  end

  defp swap_display_orders(link1, link2) do
    temp_order = link1.display_order

    case Qlink.update_link(link1, %{display_order: link2.display_order}) do
      {:ok, _} ->
        case Qlink.update_link(link2, %{display_order: temp_order}) do
          {:ok, _} ->
            updated_links =
              Qlink.list_page_links(link1.qlink_page_id) |> Repo.preload(:qlink_section)

            {:ok, updated_links}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  attr :section, QlinkSection, required: true

  def render_section_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2 p-3 bg-base-100 rounded-lg border border-base-300">
      <div class="flex items-center gap-2 flex-1 min-w-0">
        <div class="flex-1 min-w-0">
          <div class="font-medium truncate">{@section.title}</div>
          <%= if @section.description do %>
            <div class="text-sm text-base-content/60 truncate">{@section.description}</div>
          <% end %>
        </div>
      </div>
      <div class="flex items-center gap-1 flex-shrink-0">
        <button
          type="button"
          phx-click="move_section"
          phx-value-id={@section.id}
          phx-value-direction="up"
          class="btn btn-xs btn-ghost"
          title="Move up"
        >
          <.icon name="hero-arrow-up" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="move_section"
          phx-value-id={@section.id}
          phx-value-direction="down"
          class="btn btn-xs btn-ghost"
          title="Move down"
        >
          <.icon name="hero-arrow-down" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="show_edit_section_modal"
          phx-value-id={@section.id}
          class="btn btn-xs btn-ghost"
          title="Edit"
        >
          <.icon name="hero-pencil" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="delete_section"
          phx-value-id={@section.id}
          data-confirm="Are you sure you want to delete this section? Links in this section will become unsectioned."
          class="btn btn-xs btn-ghost text-error"
          title="Delete"
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  attr :link, QlinkLink, required: true
  attr :sections, :list, default: []

  def render_link_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2 p-3 bg-base-100 rounded-lg border border-base-300">
      <div class="flex items-center gap-2 flex-1 min-w-0">
        <%= if @link.icon do %>
          <span class="text-xl flex-shrink-0">{@link.icon}</span>
        <% end %>
        <div class="flex-1 min-w-0">
          <div class="font-medium truncate">{@link.title}</div>
          <%= if @link.description do %>
            <div class="text-sm text-base-content/60 truncate">{@link.description}</div>
          <% end %>
          <div class="text-xs text-base-content/40 truncate">{@link.url}</div>
        </div>
        <%= if @link.type == :embed do %>
          <span class="badge badge-info badge-sm">Embed</span>
        <% end %>
        <%= unless @link.is_visible do %>
          <span class="badge badge-warning badge-sm">Hidden</span>
        <% end %>
      </div>
      <div class="flex items-center gap-1 flex-shrink-0">
        <button
          type="button"
          phx-click="move_link"
          phx-value-id={@link.id}
          phx-value-direction="up"
          class="btn btn-xs btn-ghost"
          title="Move up"
        >
          <.icon name="hero-arrow-up" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="move_link"
          phx-value-id={@link.id}
          phx-value-direction="down"
          class="btn btn-xs btn-ghost"
          title="Move down"
        >
          <.icon name="hero-arrow-down" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="show_edit_link_modal"
          phx-value-id={@link.id}
          class="btn btn-xs btn-ghost"
          title="Edit"
        >
          <.icon name="hero-pencil" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="delete_link"
          phx-value-id={@link.id}
          data-confirm="Are you sure you want to delete this link?"
          class="btn btn-xs btn-ghost text-error"
          title="Delete"
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end
end
