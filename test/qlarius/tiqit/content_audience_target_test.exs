defmodule Qlarius.Tiqit.ContentAudienceTargetTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.Campaigns.Target
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, Creators}
  alias Qlarius.Tiqit.ContentAudienceTarget

  setup do
    {:ok, creator} =
      Creators.create_creator(%{"name" => "Aud #{System.unique_integer([:positive])}"})

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Cat #{System.unique_integer([:positive])}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Group"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{title: "Episode", date_published: ~D[2025-01-01]})
      |> Repo.insert!()

    target =
      %Target{}
      |> Target.changeset(%{title: "Audience", creator_id: creator.id})
      |> Repo.insert!()

    %{creator: creator, catalog: catalog, group: group, piece: piece, target: target}
  end

  defp attach(attrs), do: ContentAudienceTarget.changeset(%ContentAudienceTarget{}, attrs)

  describe "attachment level" do
    test "attaches at each of the four levels", ctx do
      for {key, id} <- [
            creator_id: ctx.creator.id,
            catalog_id: ctx.catalog.id,
            content_group_id: ctx.group.id,
            content_piece_id: ctx.piece.id
          ] do
        attrs = %{target_id: ctx.target.id, mode: :boost} |> Map.put(key, id)

        assert {:ok, attachment} = Repo.insert(attach(attrs))
        assert Map.get(attachment, key) == id
      end
    end

    test "rejects an attachment with no level", ctx do
      changeset = attach(%{target_id: ctx.target.id, mode: :boost})

      refute changeset.valid?

      assert "must attach to a creator, catalog, group or piece" in errors_on(changeset).content_piece_id
    end

    test "rejects an attachment at two levels at once", ctx do
      changeset =
        attach(%{
          target_id: ctx.target.id,
          mode: :boost,
          catalog_id: ctx.catalog.id,
          content_piece_id: ctx.piece.id
        })

      refute changeset.valid?
      assert "must attach to exactly one level" in errors_on(changeset).content_piece_id
    end

    test "the database rejects two levels even when the changeset is bypassed", ctx do
      assert_raise Ecto.ConstraintError, ~r/exactly_one_attachment_level_non_null/, fn ->
        %ContentAudienceTarget{}
        |> Ecto.Changeset.change(%{
          target_id: ctx.target.id,
          mode: :boost,
          catalog_id: ctx.catalog.id,
          content_piece_id: ctx.piece.id
        })
        |> Repo.insert()
      end
    end
  end

  describe "mode" do
    test "accepts boost and gate", ctx do
      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :boost, catalog_id: ctx.catalog.id})
               )

      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :gate, catalog_id: ctx.catalog.id})
               )
    end

    test "rejects anything else", ctx do
      changeset =
        attach(%{target_id: ctx.target.id, mode: :maybe, catalog_id: ctx.catalog.id})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).mode
    end

    test "is required", ctx do
      changeset = attach(%{target_id: ctx.target.id, catalog_id: ctx.catalog.id})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).mode
    end
  end

  describe "one attachment per mode per level" do
    test "a second boost on the same catalog is rejected", ctx do
      attrs = %{target_id: ctx.target.id, mode: :boost, catalog_id: ctx.catalog.id}

      assert {:ok, _} = Repo.insert(attach(attrs))
      assert {:error, changeset} = Repo.insert(attach(attrs))
      assert "has already been taken" in errors_on(changeset).mode
    end

    test "a boost and a gate can coexist on the same catalog", ctx do
      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :boost, catalog_id: ctx.catalog.id})
               )

      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :gate, catalog_id: ctx.catalog.id})
               )
    end

    test "the same level value at a different level does not collide", ctx do
      # Uniqueness is per level column, and Postgres treats NULLs as distinct,
      # so attachments at other levels never constrain each other.
      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :boost, catalog_id: ctx.catalog.id})
               )

      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :boost, content_group_id: ctx.group.id})
               )

      assert {:ok, _} =
               Repo.insert(
                 attach(%{target_id: ctx.target.id, mode: :boost, content_piece_id: ctx.piece.id})
               )
    end
  end

  describe "target reuse" do
    test "one audience serves attachments at many levels", ctx do
      for attrs <- [
            %{catalog_id: ctx.catalog.id},
            %{content_group_id: ctx.group.id},
            %{content_piece_id: ctx.piece.id}
          ] do
        assert {:ok, _} =
                 Repo.insert(attach(Map.merge(%{target_id: ctx.target.id, mode: :boost}, attrs)))
      end

      assert Repo.aggregate(
               from(a in ContentAudienceTarget, where: a.target_id == ^ctx.target.id),
               :count
             ) == 3
    end

    test "deleting the target removes its attachments", ctx do
      {:ok, attachment} =
        Repo.insert(attach(%{target_id: ctx.target.id, mode: :boost, catalog_id: ctx.catalog.id}))

      Repo.delete!(ctx.target)

      refute Repo.get(ContentAudienceTarget, attachment.id)
    end

    test "deleting the content removes its attachments", ctx do
      {:ok, attachment} =
        Repo.insert(
          attach(%{target_id: ctx.target.id, mode: :boost, content_piece_id: ctx.piece.id})
        )

      Repo.delete!(ctx.piece)

      refute Repo.get(ContentAudienceTarget, attachment.id)
    end
  end

  describe "attachment level is not ownership" do
    test "a marketer-owned target can still be attached to content", ctx do
      marketer =
        %Marketer{}
        |> Marketer.changeset(%{business_name: "M #{System.unique_integer([:positive])}"})
        |> Repo.insert!()

      marketer_target =
        %Target{}
        |> Target.changeset(%{title: "Marketer audience", marketer_id: marketer.id})
        |> Repo.insert!()

      # The schema does not police this — `content_audience_targets.creator_id`
      # is the attachment level, not ownership. Keeping owners apart is the
      # context layer's job, so this documents where the boundary is not.
      assert {:ok, _} =
               Repo.insert(
                 attach(%{
                   target_id: marketer_target.id,
                   mode: :boost,
                   catalog_id: ctx.catalog.id
                 })
               )
    end
  end
end
