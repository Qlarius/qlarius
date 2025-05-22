defmodule QlariusWeb.Creators.ContentGroupLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Creators

  alias QlariusWeb.TiqitClassHTML

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    group = Creators.get_content_group!(id)
    catalog = group.catalog
    creator = catalog.creator

    changeset = Creators.change_content_group(group)

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog}"},
      {group.title, ~p"/creators/content_groups/#{group}"},
      {"Edit", ~p"/creators/content_groups/#{group}/edit"}
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
    |> noreply()
  end

  # NEW
  def handle_params(%{"catalog_id" => catalog_id}, _uri, socket) do
    changeset = Creators.change_content_group(%ContentGroup{})
    catalog = Creators.get_catalog!(catalog_id)
    creator = catalog.creator

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator}"},
      {catalog.name, ~p"/creators/catalogs/#{catalog}"},
      {"New Content Group", ~p"/creators/catalogs/#{catalog}/content_groups/new"}
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

  defp save_group(socket, :edit, group_params) do
    case Creators.update_content_group(socket.assigns.group, group_params) do
      {:ok, group} ->
        socket
        |> put_flash(:info, "Group updated successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_group(socket, :new, group_params) do
    catalog = socket.assigns.catalog

    case Creators.create_content_group(catalog, group_params) do
      {:ok, group} ->
        socket
        |> put_flash(:info, "Group created successfully")
        |> push_navigate(to: ~p"/creators/content_groups/#{group}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
