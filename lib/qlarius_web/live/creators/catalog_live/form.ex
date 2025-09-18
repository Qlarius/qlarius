defmodule QlariusWeb.Creators.CatalogLive.Form do
  use QlariusWeb, :live_view

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Repo

  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Uploaders.CreatorImage

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
    |> allow_upload(:image,
      accept: ~w(.jpg .jpeg .png .gif .webp),
      max_entries: 1,
      max_file_size: 10_000_000
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
    |> allow_upload(:image,
      accept: ~w(.jpg .jpeg .png .gif .webp),
      max_entries: 1,
      max_file_size: 10_000_000
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

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("write_default_tiqit_classes", _params, socket) do
    # Call the arcade context function to write default tiqit classes for this catalog
    Qlarius.Tiqit.Arcade.Arcade.write_default_catalog_tiqit_classes(socket.assigns.catalog)

    # Reload the catalog to get updated tiqit classes
    catalog = Qlarius.Tiqit.Arcade.Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply, assign(socket, :catalog, catalog)}
  end

  # error helpers grouped after all handle_event clauses to avoid compiler warnings
  defp error_to_string(:too_large), do: "File too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp save_catalog(socket, :edit, catalog_params) do
    # Handle file upload for LiveView - store with Waffle directly
    catalog_params_with_image =
      case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
             upload = %Plug.Upload{
               path: path,
               filename: entry.client_name,
               content_type: entry.client_type
             }

             case CreatorImage.store({upload, socket.assigns.catalog}) do
               {:ok, filename} -> {:ok, filename}
               error -> error
             end
           end) do
        [filename | _] -> Map.put(catalog_params, "image", filename)
        [] -> catalog_params
      end

    case Creators.update_catalog(socket.assigns.catalog, catalog_params_with_image) do
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

    # Create a temporary catalog for Waffle store function
    temp_catalog = %Catalog{creator_id: creator.id}

    # Handle file upload for LiveView - store with Waffle directly
    catalog_params_with_image =
      case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
             upload = %Plug.Upload{
               path: path,
               filename: entry.client_name,
               content_type: entry.client_type
             }

             case CreatorImage.store({upload, temp_catalog}) do
               {:ok, filename} -> {:ok, filename}
               error -> error
             end
           end) do
        [filename | _] -> Map.put(catalog_params, "image", filename)
        [] -> catalog_params
      end

    case Creators.create_catalog(creator, catalog_params_with_image) do
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
