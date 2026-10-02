defmodule QlariusWeb.Creators.ContentGroupLive.Form do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.Creators

  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.LiveView.ImageUpload

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    group = Creators.get_content_group!(id)
    catalog = group.catalog
    creator = catalog.creator

    changeset = Creators.change_content_group(group)

    crumbs = [
      {creator.name, ~p"/creators/#{creator.id}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog.id}"},
      {group.title, ~p"/creators/content_groups/#{group.id}"}
    ]

    socket
    |> assign(
      crumbs: crumbs,
      catalog: catalog,
      creator: creator,
      group: group,
      form: to_form(changeset),
      page_title: "Edit #{Catalog.type_label(catalog.group_type, 1, capitalize: false)}"
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  # NEW
  def handle_params(%{"catalog_id" => catalog_id}, _uri, socket) do
    changeset = Creators.change_content_group(%ContentGroup{})
    catalog = Creators.get_catalog!(catalog_id)
    creator = catalog.creator

    crumbs = [
      {creator.name, ~p"/creators/#{creator.id}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog.id}"}
    ]

    socket
    |> assign(
      crumbs: crumbs,
      catalog: catalog,
      creator: catalog.creator,
      form: to_form(changeset),
      group: %ContentGroup{},
      page_title: "New #{Catalog.type_label(catalog.group_type, 1, capitalize: false)}"
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"content_group" => group_params}, socket) do
    form =
      socket.assigns.group
      |> Creators.change_content_group(group_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"content_group" => group_params}, socket) do
    save_group(socket, socket.assigns.live_action, group_params)
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("delete_image", _params, socket) do
    case Creators.delete_content_group_image(socket.assigns.group) do
      {:ok, group} ->
        socket
        |> assign(group: group)
        |> put_flash(:info, "Image deleted successfully")

      {:error, _changeset} ->
        put_flash(socket, :error, "Failed to delete image")
    end
    |> noreply()
  end

  def handle_event("write_default_tiqit_classes", _params, socket) do
    Qlarius.Tiqit.Arcade.Arcade.write_default_group_tiqit_classes(socket.assigns.group)

    group = Creators.get_content_group!(socket.assigns.group.id)

    {:noreply,
     socket
     |> assign(:group, group)
     |> assign(:form, to_form(Creators.change_content_group(group)))}
  end

  defp save_group(socket, :edit, group_params) do
    group_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        socket.assigns.group,
        QlariusWeb.Uploaders.CreatorImage,
        group_params
      )

    case Creators.update_content_group(socket.assigns.group, group_params_with_image) do
      {:ok, group} ->
        socket
        |> put_flash(:info, "Group updated successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("ContentGroup update failed: #{inspect(changeset.errors)}")
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_group(socket, :new, group_params) do
    catalog = socket.assigns.catalog
    temp_group = %Qlarius.Tiqit.Arcade.ContentGroup{catalog: catalog}

    group_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        temp_group,
        QlariusWeb.Uploaders.CreatorImage,
        group_params
      )

    case Creators.create_content_group(catalog, group_params_with_image) do
      {:ok, group} ->
        socket
        |> put_flash(:info, "Group created successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("ContentGroup create failed: #{inspect(changeset.errors)}")
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :description, :string, default: nil

  defp toggle_row(assigns) do
    ~H"""
    <label class="flex cursor-pointer items-start justify-between gap-4 px-6 py-4 transition-colors hover:bg-base-200/40">
      <span class="min-w-0">
        <span class="block text-sm font-medium">{@label}</span>
        <span :if={@description} class="mt-0.5 block text-sm text-base-content/60">
          {@description}
        </span>
      </span>
      <input type="hidden" name={@field.name} value="false" />
      <input
        type="checkbox"
        id={@field.id}
        name={@field.name}
        value="true"
        checked={Phoenix.HTML.Form.normalize_value("checkbox", @field.value)}
        class="toggle toggle-primary toggle-sm mt-0.5 shrink-0"
      />
    </label>
    """
  end
end
