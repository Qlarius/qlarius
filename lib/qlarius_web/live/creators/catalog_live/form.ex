defmodule QlariusWeb.Creators.CatalogLive.Form do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Repo

  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.LiveView.ImageUpload

  # EDIT
  @impl true
  def handle_params(%{"id" => id}, _uri, %{assigns: %{live_action: :edit}} = socket) do
    catalog =
      Creators.get_catalog!(id)
      |> Repo.preload(:tiqit_classes)

    creator = catalog.creator

    changeset = Creators.change_catalog(catalog)

    breadcrumbs = [
      {creator.name, ~p"/creators_cont/#{creator}"},
      {catalog.name, ~p"/creators_cont/#{catalog}"},
      {"Edit", ~p"/creators_cont/catalogs/#{catalog}/edit"}
    ]

    socket
    |> assign(catalog: catalog, creator: creator)
    |> assign(
      breadcrumbs: breadcrumbs,
      form: to_form(changeset),
      page_title: "Edit Catalog"
    )
    |> ImageUpload.setup_upload(:image)
    |> noreply()
  end

  # NEW — supports both `:creator_id` (creator self-serve route) and
  # `:id` (admin route nested under `resources "/", CreatorController`).
  @impl true
  def handle_params(params, _uri, %{assigns: %{live_action: :new}} = socket) do
    creator_id = params["creator_id"] || params["id"]
    creator = Creators.get_creator!(creator_id)
    changeset = Creators.change_catalog(%Catalog{})

    breadcrumbs = [
      {creator.name, ~p"/creators/#{creator.id}"},
      {"New catalog", ~p"/creators/#{creator.id}/catalogs/new"}
    ]

    socket
    |> assign(
      breadcrumbs: breadcrumbs,
      catalog: %Catalog{},
      creator: creator,
      form: to_form(changeset),
      page_title: "New Catalog"
    )
    |> ImageUpload.setup_upload(:image)
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

  def handle_event("delete_image", _params, socket) do
    case Creators.delete_catalog_image(socket.assigns.catalog) do
      {:ok, catalog} ->
        socket
        |> assign(catalog: catalog)
        |> put_flash(:info, "Image deleted successfully")

      {:error, _changeset} ->
        put_flash(socket, :error, "Failed to delete image")
    end
    |> noreply()
  end

  def handle_event("write_default_tiqit_classes", _params, socket) do
    Qlarius.Tiqit.Arcade.Arcade.write_default_catalog_tiqit_classes(socket.assigns.catalog)

    catalog =
      socket.assigns.catalog.id
      |> Creators.get_catalog!()
      |> Repo.preload(:tiqit_classes, force: true)

    unsaved_params =
      Map.drop(socket.assigns.form.params || %{}, [
        "tiqit_classes",
        "tiqit_class_sort",
        "tiqit_class_drop"
      ])

    form = catalog |> Creators.change_catalog(unsaved_params) |> to_form()

    {:noreply, assign(socket, catalog: catalog, form: form)}
  end

  defp save_catalog(socket, :edit, catalog_params) do
    catalog_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        socket.assigns.catalog,
        CreatorImage,
        catalog_params
      )

    case Creators.update_catalog(socket.assigns.catalog, catalog_params_with_image) do
      {:ok, catalog} ->
        socket
        |> put_flash(:info, "Catalog updated successfully")
        |> push_navigate(to: ~p"/creators/catalogs/#{catalog.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp save_catalog(socket, :new, catalog_params) do
    creator = socket.assigns.creator
    temp_catalog = %Catalog{creator_id: creator.id}

    catalog_params_with_image =
      ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        temp_catalog,
        CreatorImage,
        catalog_params
      )

    case Creators.create_catalog(creator, catalog_params_with_image) do
      {:ok, catalog} ->
        socket
        |> put_flash(:info, "Catalog created successfully")
        |> push_navigate(to: ~p"/creators/catalogs/#{catalog.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        assign(socket, :form, to_form(changeset, action: :validate))
    end
    |> noreply()
  end

  defp type_options(types), do: Enum.map(types, &{Catalog.type_label(&1), &1})

  defp selected_type(form, field, types) do
    case form[field].value do
      value when value in [nil, ""] -> List.first(types)
      value -> value
    end
  end

  defp type_word(form, field, types, count \\ 1) do
    Catalog.type_label(selected_type(form, field, types), count, capitalize: false)
  end

  defp structure_preview(form) do
    [
      selected_type(form, :type, Catalog.types()),
      selected_type(form, :group_type, Catalog.group_types()),
      selected_type(form, :piece_type, Catalog.piece_types())
    ]
    |> Enum.map_join(" › ", &Catalog.type_label/1)
  end
end
