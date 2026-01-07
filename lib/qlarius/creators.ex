defmodule Qlarius.Creators do
  @moduledoc """
  The Creators context.
  Handles creator profiles and memberships.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Creators.Creator
  alias Qlarius.Creators.CreatorMembership
  alias Qlarius.Accounts.User

  @doc """
  Returns the list of all creators.
  """
  def list_creators do
    from(c in Creator, order_by: [asc: c.name])
    |> Repo.all()
    |> Repo.preload([:catalogs, qlink_pages: [:creator]])
  end

  @doc """
  Returns the list of creators for a given user.
  """
  def list_user_creators(%User{} = user) do
    user
    |> Ecto.assoc(:creators)
    |> Repo.all()
    |> Repo.preload([:catalogs, qlink_pages: [:creator]])
  end

  @doc """
  Gets a single creator.
  Raises `Ecto.NoResultsError` if the Creator does not exist.
  """
  def get_creator!(id) do
    Repo.get!(Creator, id)
    |> Repo.preload([
      :users,
      qlink_pages: [:creator],
      catalogs: [
        :creator,
        :content_groups,
        :tiqit_classes,
        content_groups: [:content_pieces, :tiqit_classes]
      ]
    ])
  end

  @doc """
  Gets a creator for a specific user, ensuring they have access.
  """
  def get_user_creator!(user_id, creator_id) do
    query =
      from c in Creator,
        join: cm in CreatorMembership,
        on: cm.creator_id == c.id,
        where: cm.user_id == ^user_id and c.id == ^creator_id,
        preload: [:qlink_pages, :catalogs]

    Repo.one!(query)
  end

  @doc """
  Creates a creator (without user association - for admin/legacy use).
  """
  def create_creator(attrs \\ %{}) do
    attrs =
      Map.put_new(attrs, :referral_code, Qlarius.Referrals.generate_referral_code("creator"))

    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &Creator.changeset_with_image/2,
        else: &Creator.changeset/2

    %Creator{}
    |> changeset_fn.(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a creator and associates it with a user as owner.
  """
  def create_creator_with_user(attrs \\ %{}, user_id) do
    Repo.transaction(fn ->
      with {:ok, creator} <- do_create_creator(attrs),
           {:ok, _membership} <- create_creator_membership(creator.id, user_id, :owner) do
        creator
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_create_creator(attrs) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &Creator.changeset_with_image/2,
        else: &Creator.changeset/2

    %Creator{}
    |> changeset_fn.(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a creator.
  """
  def update_creator(%Creator{} = creator, attrs) do
    changeset_fn =
      if Map.has_key?(attrs, "image"),
        do: &Creator.changeset_with_image/2,
        else: &Creator.changeset/2

    creator
    |> changeset_fn.(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a creator.
  """
  def delete_creator(%Creator{} = creator) do
    Repo.delete(creator)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking creator changes.
  """
  def change_creator(%Creator{} = creator, attrs \\ %{}) do
    Creator.changeset(creator, attrs)
  end

  @doc """
  Deletes a creator's image.
  """
  def delete_creator_image(%Creator{} = creator) do
    creator
    |> Ecto.Changeset.change(%{image: nil})
    |> Repo.update()
  end

  @doc """
  Checks if a user has access to a creator.
  """
  def user_has_creator_access?(user_id, creator_id) do
    query =
      from cm in CreatorMembership,
        where: cm.user_id == ^user_id and cm.creator_id == ^creator_id

    Repo.exists?(query)
  end

  @doc """
  Gets the role of a user for a creator.
  """
  def get_user_role(user_id, creator_id) do
    query =
      from cm in CreatorMembership,
        where: cm.user_id == ^user_id and cm.creator_id == ^creator_id,
        select: cm.role

    Repo.one(query)
  end

  # Creator Memberships

  @doc """
  Creates a creator membership.
  """
  def create_creator_membership(creator_id, user_id, role \\ :member) do
    %CreatorMembership{}
    |> CreatorMembership.changeset(%{
      creator_id: creator_id,
      user_id: user_id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Lists all members of a creator.
  """
  def list_creator_members(creator_id) do
    query =
      from cm in CreatorMembership,
        where: cm.creator_id == ^creator_id,
        preload: [:user]

    Repo.all(query)
  end
end
