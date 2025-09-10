defmodule QlariusWeb.Creators.CatalogLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Repo

  alias QlariusWeb.TiqitClassHTML

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    catalog =
      Creators.get_catalog!(id)
      |> Repo.preload(:tiqit_classes)

    creator = catalog.creator

    changeset = Creators.change_catalog(catalog)

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator}"},
      {catalog.name, ~p"/creators/#{catalog}"},
      {"Edit", ~p"/creators/catalogs/#{catalog}/edit"}
    ]

    socket
    |> assign(catalog: catalog, creator: creator)
    |> assign(
      breadcrumbs: breadcrumbs,
      form: to_form(changeset),
      page_title: "Edit Catalog"
    )
    |> noreply()
  end

  # NEW
  @impl true
  def handle_params(%{"creator_id" => creator_id}, _uri, socket) do
    creator = Creators.get_creator!(creator_id)
    changeset = Creators.change_catalog(%Catalog{})

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator}"},
      {"New catalog", ~p"/creators/#{creator}/catalogs/new"}
    ]

    socket
    |> assign(
      breadcrumbs: breadcrumbs,
      catalog: %Catalog{},
      creator: creator,
      form: to_form(changeset),
      page_title: "New Catalog"
    )
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"catalog" => catalog_params}, socket) do
    form =
      socket.assigns.catalog
      |> Creators.change_catalog(catalog_params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"catalog" => catalog_params}, socket) do
    save_catalog(socket, socket.assigns.live_action, catalog_params)
  end

  def handle_event("write_default_tiqit_classes", _params, socket) do
    # Call the arcade context function to write default tiqit classes for this catalog
    Qlarius.Tiqit.Arcade.Arcade.write_default_catalog_tiqit_classes(socket.assigns.catalog)

    # Reload the catalog to get updated tiqit classes
    catalog = Qlarius.Tiqit.Arcade.Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply, assign(socket, :catalog, catalog)}
  end

  defp save_catalog(socket, :edit, catalog_params) do
    case Creators.update_catalog(socket.assigns.catalog, catalog_params) do
      {:ok, catalog} ->
        socket
        |> put_flash(:info, "Catalog updated successfully")
        |> push_navigate(to: ~p"/creators/catalogs/#{catalog}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_catalog(socket, :new, catalog_params) do
    creator = socket.assigns.creator

    case Creators.create_catalog(creator, catalog_params) do
      {:ok, catalog} ->
        socket
        |> put_flash(:info, "Catalog created successfully")
        |> push_navigate(to: ~p"/creators/catalogs/#{catalog}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end
end
