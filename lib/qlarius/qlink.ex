defmodule Qlarius.Qlink do
  @moduledoc """
  The Qlink context.
  Handles link-in-bio pages, links, sections, and analytics.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Qlink.QlinkPage
  alias Qlarius.Qlink.QlinkLink
  alias Qlarius.Qlink.QlinkSection
  alias Qlarius.Qlink.PageView

  # QlinkPages

  @doc """
  Returns the list of qlink pages for a creator.
  """
  def list_creator_pages(creator_id) do
    QlinkPage
    |> where([p], p.creator_id == ^creator_id)
    |> Repo.all()
  end

  @doc """
  Gets a single qlink page by ID.
  """
  def get_page!(id) do
    Repo.get!(QlinkPage, id)
    |> Repo.preload([:creator, :qlink_sections, :qlink_links])
  end

  @doc """
  Gets a single qlink page by alias.
  """
  def get_page_by_alias(alias) do
    QlinkPage
    |> where([p], p.alias == ^alias)
    |> Repo.one()
    |> case do
      nil -> nil
      page -> Repo.preload(page, [:creator, :qlink_sections, :qlink_links])
    end
  end

  @doc """
  Creates a qlink page.
  """
  def create_page(attrs \\ %{}) do
    %QlinkPage{}
    |> QlinkPage.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a qlink page.
  """
  def update_page(%QlinkPage{} = page, attrs) do
    require Logger
    Logger.debug("Qlink.update_page - attrs: #{inspect(attrs)}")

    Logger.debug(
      "Qlink.update_page - social_links in attrs: #{inspect(Map.get(attrs, "social_links"))}"
    )

    changeset = QlinkPage.changeset(page, attrs)
    Logger.debug("Qlink.update_page - changeset changes: #{inspect(changeset.changes)}")
    Logger.debug("Qlink.update_page - changeset errors: #{inspect(changeset.errors)}")

    result = Repo.update(changeset)

    case result do
      {:ok, updated_page} ->
        Logger.debug(
          "Qlink.update_page - success, social_links: #{inspect(updated_page.social_links)}"
        )

        result

      {:error, changeset} ->
        Logger.debug("Qlink.update_page - error, changeset errors: #{inspect(changeset.errors)}")
        result
    end
  end

  @doc """
  Deletes a qlink page.
  """
  def delete_page(%QlinkPage{} = page) do
    Repo.delete(page)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page changes.
  """
  def change_page(%QlinkPage{} = page, attrs \\ %{}) do
    QlinkPage.changeset(page, attrs)
  end

  @doc """
  Checks if an alias is available.
  """
  def alias_available?(alias) do
    !Repo.exists?(from p in QlinkPage, where: p.alias == ^alias)
  end

  # QlinkSections

  @doc """
  Lists all sections for a page.
  """
  def list_page_sections(page_id) do
    QlinkSection
    |> where([s], s.qlink_page_id == ^page_id)
    |> order_by([s], s.display_order)
    |> Repo.all()
  end

  @doc """
  Gets a single section.
  """
  def get_section!(id) do
    Repo.get!(QlinkSection, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking section changes.
  """
  def change_section(%QlinkSection{} = section, attrs \\ %{}) do
    QlinkSection.changeset(section, attrs)
  end

  @doc """
  Creates a section.
  """
  def create_section(attrs \\ %{}) do
    %QlinkSection{}
    |> QlinkSection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section.
  """
  def update_section(%QlinkSection{} = section, attrs) do
    section
    |> QlinkSection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a section.
  """
  def delete_section(%QlinkSection{} = section) do
    Repo.delete(section)
  end

  # QlinkLinks

  @doc """
  Lists all links for a page, ordered by display_order.
  """
  def list_page_links(page_id) do
    QlinkLink
    |> where([l], l.qlink_page_id == ^page_id)
    |> order_by([l], l.display_order)
    |> Repo.all()
  end

  @doc """
  Lists visible links for a page (public view).
  """
  def list_visible_links(page_id) do
    QlinkLink
    |> where([l], l.qlink_page_id == ^page_id and l.is_visible == true)
    |> order_by([l], l.display_order)
    |> Repo.all()
    |> Repo.preload(:recipient)
  end

  @doc """
  Gets a single link.
  """
  def get_link!(id) do
    Repo.get!(QlinkLink, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking link changes.
  """
  def change_link(%QlinkLink{} = link, attrs \\ %{}) do
    QlinkLink.changeset(link, attrs)
  end

  @doc """
  Creates a link.
  """
  def create_link(attrs \\ %{}) do
    %QlinkLink{}
    |> QlinkLink.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a link.
  """
  def update_link(%QlinkLink{} = link, attrs) do
    link
    |> QlinkLink.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a link.
  """
  def delete_link(%QlinkLink{} = link) do
    Repo.delete(link)
  end

  @doc """
  Increments the click count for a link.
  """
  def increment_link_clicks(%QlinkLink{} = link) do
    link
    |> Ecto.Changeset.change(click_count: link.click_count + 1)
    |> Repo.update()
  end

  # Analytics

  @doc """
  Records a page view event.
  """
  def record_page_view(attrs) do
    %PageView{}
    |> PageView.changeset(attrs)
    |> Repo.insert()

    # Increment page view counter
    increment_page_views(attrs.qlink_page_id)
  end

  @doc """
  Records a link click event.
  """
  def record_link_click(attrs) do
    %PageView{}
    |> PageView.changeset(Map.put(attrs, :event_type, :link_click))
    |> Repo.insert()

    # Increment counters
    increment_page_clicks(attrs.qlink_page_id)

    if link_id = attrs[:qlink_link_id] do
      link = get_link!(link_id)
      increment_link_clicks(link)
    end
  end

  defp increment_page_views(page_id) do
    from(p in QlinkPage, where: p.id == ^page_id)
    |> Repo.update_all(inc: [view_count: 1])
  end

  defp increment_page_clicks(page_id) do
    from(p in QlinkPage, where: p.id == ^page_id)
    |> Repo.update_all(inc: [total_clicks: 1])
  end

  @doc """
  Gets display image for a page (with cascade fallback).
  Falls back to creator image if page has no profile photo.
  """
  def get_display_image(%QlinkPage{} = page) do
    alias QlariusWeb.Uploaders.CreatorImage

    cond do
      page.profile_photo ->
        CreatorImage.url({page.profile_photo, page}, :original)

      page.creator && Ecto.assoc_loaded?(page.creator) && page.creator.image ->
        CreatorImage.url({page.creator.image, page.creator}, :original)

      true ->
        "/images/default_avatar.png"
    end
  end
end
