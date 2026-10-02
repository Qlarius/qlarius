defmodule QlariusWeb.Creators.CatalogLive.Show do
  use QlariusWeb, :live_view

  import QlariusWeb.Components.MarketerUI

  alias QlariusWeb.Components.{AdminSidebar, AdminTopbar}
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Tiqit.ContentAudiences
  alias QlariusWeb.AudienceCard
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias QlariusWeb.TiqitClassHTML
  alias QlariusWeb.Helpers.ImageHelpers
  import QlariusWeb.CoreComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    catalog = Creators.get_catalog!(id)
    creator = catalog.creator

    {:ok,
     socket
     |> assign(:catalog, catalog)
     |> assign(:creator, creator)
     |> assign(:page_title, catalog.name)
     |> assign(:audience, ContentAudiences.effective_audience(catalog))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    catalog = socket.assigns.catalog
    creator = catalog.creator
    {:ok, _catalog} = Creators.delete_catalog(catalog)

    {:noreply,
     socket
     |> put_flash(:info, "Catalog deleted successfully")
     |> push_navigate(to: ~p"/creators/#{creator.id}")}
  end

  def handle_event("add_default_tiqit_classes", _params, socket) do
    Arcade.write_default_catalog_tiqit_classes(socket.assigns.catalog)

    catalog = Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply,
     socket
     |> assign(:catalog, catalog)
     |> put_flash(:info, "Default Tiqit classes added successfully")}
  end

  def handle_event("delete_tiqit_class", %{"id" => id}, socket) do
    {:ok, _} = Creators.delete_tiqit_class(id)

    catalog = Creators.get_catalog!(socket.assigns.catalog.id)

    {:noreply,
     socket
     |> assign(:catalog, catalog)
     |> put_flash(:info, "Tiqit class deleted successfully")}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        catalog_label: Catalog.type_label(assigns.catalog.type),
        group_label: Catalog.type_label(assigns.catalog.group_type),
        groups_label: Catalog.type_label(assigns.catalog.group_type, 2),
        groups: Enum.map(assigns.catalog.content_groups, &%{&1 | catalog: assigns.catalog}),
        has_image:
          ImageHelpers.catalog_image_url(assigns.catalog) != ImageHelpers.placeholder_image_url()
      )

    ~H"""
    <Layouts.admin {assigns}>
      <div class="flex h-screen">
        <AdminSidebar.sidebar current_user={@current_scope.user} />

        <div class="flex min-w-0 grow flex-col">
          <AdminTopbar.topbar current_user={@current_scope.user} />

          <div class="overflow-auto">
            <.page class="max-w-7xl">
              <.page_header
                title={@catalog.name}
                subtitle={"#{@catalog_label} by #{@creator.name}"}
                crumbs={[{@creator.name, ~p"/creators/#{@creator.id}"}]}
              >
                <:actions>
                  <.link
                    navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-pencil-square" class="size-4" /> Edit
                  </.link>
                  <button
                    type="button"
                    phx-click="delete"
                    data-confirm={"Are you sure you want to delete this #{Catalog.type_label(@catalog.type, 1, capitalize: false)}?"}
                    class="btn btn-ghost btn-sm text-error"
                  >
                    <.icon name="hero-trash" class="size-4" /> Delete
                  </button>
                </:actions>
              </.page_header>

              <div class="grid items-start gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
                <.panel
                  id="catalog-groups"
                  flush
                  title={@groups_label}
                  description={group_count_label(@catalog)}
                >
                  <:actions>
                    <.link
                      navigate={~p"/creators/catalogs/#{@catalog.id}/content_groups/new"}
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-plus" class="size-4" /> New {String.downcase(@group_label)}
                    </.link>
                  </:actions>

                  <.empty_state
                    :if={@catalog.content_groups == []}
                    icon="hero-folder"
                    title={"No #{Catalog.type_label(@catalog.group_type, 2, capitalize: false)} yet"}
                  >
                    Start building this {Catalog.type_label(@catalog.type, 1, capitalize: false)} by adding {Catalog.type_with_article(
                      @catalog.group_type
                    )}.
                    <:action>
                      <.link
                        navigate={~p"/creators/catalogs/#{@catalog.id}/content_groups/new"}
                        class="btn btn-primary btn-sm"
                      >
                        <.icon name="hero-plus" class="size-4" />
                        Add first {Catalog.type_label(@catalog.group_type, 1, capitalize: false)}
                      </.link>
                    </:action>
                  </.empty_state>

                  <ul :if={@catalog.content_groups != []} class="divide-y divide-base-300">
                    <li
                      :for={group <- @groups}
                      id={"content-group-#{group.id}"}
                      class="relative flex items-center gap-4 px-6 py-4 transition-colors hover:bg-base-200/40"
                    >
                      <%= if ImageHelpers.group_image_url(group) != ImageHelpers.placeholder_image_url() do %>
                        <img
                          src={ImageHelpers.group_image_url(group)}
                          alt=""
                          class="size-12 shrink-0 rounded-lg object-cover"
                        />
                      <% else %>
                        <span class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-base-200 font-semibold text-base-content/70">
                          {String.first(group.title || "?")}
                        </span>
                      <% end %>
                      <div class="min-w-0 flex-1">
                        <.link
                          navigate={~p"/creators/content_groups/#{group.id}"}
                          class="block truncate font-semibold after:absolute after:inset-0 hover:underline"
                        >
                          {group.title}
                        </.link>
                        <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
                          <span class="text-xs text-base-content/50">
                            {piece_count_label(@catalog, group)}
                          </span>
                          <TiqitClassHTML.price_chips
                            :if={group.tiqit_classes != []}
                            tiqit_classes={group.tiqit_classes}
                          />
                          <span
                            :if={group.tiqit_classes == []}
                            class="text-xs text-base-content/40"
                          >
                            No {String.downcase(@group_label)} pass
                          </span>
                        </div>
                      </div>
                      <div class="relative z-10 flex shrink-0 items-center gap-1">
                        <.icon_button
                          icon="hero-eye"
                          label="View"
                          navigate={~p"/creators/content_groups/#{group.id}"}
                        />
                        <.icon_button
                          icon="hero-pencil-square"
                          label="Edit"
                          navigate={~p"/creators/content_groups/#{group.id}/edit"}
                        />
                      </div>
                    </li>
                  </ul>
                </.panel>

                <aside class="space-y-6 lg:sticky lg:top-6">
                  <.panel id="catalog-overview" title="Overview">
                    <img
                      :if={@has_image}
                      src={ImageHelpers.catalog_image_url(@catalog)}
                      alt={"#{@catalog.name} image"}
                      class="aspect-square w-full rounded-xl border border-base-300 object-cover"
                    />
                    <.link
                      :if={!@has_image}
                      navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                      class="flex h-24 items-center justify-center gap-2 rounded-xl border border-dashed border-base-300 bg-base-200/40 text-sm text-base-content/50 hover:text-base-content"
                    >
                      <.icon name="hero-photo" class="size-5" /> Add an image
                    </.link>
                    <dl class="grid grid-cols-2 gap-x-6 gap-y-4">
                      <div class="col-span-2">
                        <.detail_item label="URL">
                          <.link
                            :if={@catalog.url}
                            href={@catalog.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            class="inline-flex items-center gap-1 break-all link link-hover"
                          >
                            {@catalog.url}
                            <.icon
                              name="hero-arrow-top-right-on-square"
                              class="size-3.5 shrink-0 text-base-content/50"
                            />
                          </.link>
                          <span :if={!@catalog.url} class="text-base-content/40">-</span>
                        </.detail_item>
                      </div>
                      <div class="col-span-2">
                        <.detail_item label="Structure" value={structure_label(@catalog)} />
                      </div>
                      <.detail_item
                        label="Undo limit"
                        value={
                          if @catalog.tiqit_undo_limit,
                            do: "#{@catalog.tiqit_undo_limit} per consumer",
                            else: "Unlimited"
                        }
                      />
                      <.detail_item
                        label="Tiqit Up"
                        value={if @catalog.tiqit_up_enabled, do: "On", else: "Off"}
                      />
                    </dl>
                  </.panel>

                  <.panel
                    id="catalog-pricing"
                    flush
                    title={"#{@catalog_label} pass"}
                    description={"Access to everything in this #{Catalog.type_label(@catalog.type, 1, capitalize: false)} for a set time."}
                  >
                    <:actions :if={@catalog.tiqit_classes != []}>
                      <.link
                        navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                        class="btn btn-ghost btn-sm"
                      >
                        Edit
                      </.link>
                    </:actions>
                    <TiqitClassHTML.tiqit_classes_table
                      :if={@catalog.tiqit_classes != []}
                      record={@catalog}
                      on_delete="delete_tiqit_class"
                    />
                    <div :if={@catalog.tiqit_classes == []} class="space-y-3 px-6 py-5">
                      <p class="text-sm text-base-content/60">
                        No {String.downcase(@catalog_label)} pass prices yet.
                      </p>
                      <div class="flex flex-wrap gap-2">
                        <button
                          type="button"
                          phx-click="add_default_tiqit_classes"
                          class="btn btn-primary btn-sm"
                        >
                          <.icon name="hero-plus" class="size-4" /> Add default prices
                        </button>
                        <.link
                          navigate={~p"/creators/catalogs/#{@catalog.id}/edit"}
                          class="btn btn-ghost btn-sm"
                        >
                          Edit prices
                        </.link>
                      </div>
                    </div>
                  </.panel>

                  <AudienceCard.card
                    creator={@creator}
                    content={@catalog}
                    effective={@audience}
                    level={:catalog}
                    class={nil}
                  />
                </aside>
              </div>
            </.page>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp structure_label(catalog) do
    [catalog.type, catalog.group_type, catalog.piece_type]
    |> Enum.map_join(" › ", &Catalog.type_label/1)
  end

  defp group_count_label(catalog) do
    count = length(catalog.content_groups)
    groups = Catalog.type_label(catalog.group_type, count, capitalize: false)
    "#{count} #{groups} in this #{Catalog.type_label(catalog.type, 1, capitalize: false)}."
  end

  defp piece_count_label(catalog, group) do
    count = length(ContentGroup.active_content_pieces(group.content_pieces))
    "#{count} #{Catalog.type_label(catalog.piece_type, count, capitalize: false)}"
  end
end
