defmodule QlariusWeb.Creators.ContentGroupLive.Form do
  use QlariusWeb, :live_view

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
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

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator.id}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog.id}"},
      {group.title, ~p"/creators/content_groups/#{group.id}"},
      {"Edit", ~p"/creators/content_groups/#{group.id}/edit"}
    ]

    socket
    |> assign(
      breadcrumbs: breadcrumbs,
      catalog: catalog,
      creator: creator,
      group: group,
      form: to_form(changeset),
      page_title: "Edit Content Group"
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  # NEW
  def handle_params(%{"catalog_id" => catalog_id}, _uri, socket) do
    changeset = Creators.change_content_group(%ContentGroup{})
    catalog = Creators.get_catalog!(catalog_id)
    creator = catalog.creator

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator.id}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog.id}"},
      {"New Content Group", ~p"/creators/catalogs/#{catalog.id}/content_groups/new"}
    ]

    socket
    |> assign(
      breadcrumbs: breadcrumbs,
      catalog: catalog,
      creator: catalog.creator,
      form: to_form(changeset),
      group: %ContentGroup{},
      page_title: "New Content Group"
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
    # Call the arcade context function to write default tiqit classes for this group
    Qlarius.Tiqit.Arcade.Arcade.write_default_group_tiqit_classes(socket.assigns.group)

    # Reload the group to get updated tiqit classes
    group = Qlarius.Tiqit.Arcade.Creators.get_content_group!(socket.assigns.group.id)

    {:noreply, assign(socket, :group, group)}
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
end
